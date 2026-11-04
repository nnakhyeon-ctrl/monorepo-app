// Fixed app-local inspection only: never signs, installs, uploads or logs matches.
import { readFileSync, writeFileSync, lstatSync, realpathSync } from 'node:fs';
import { resolve, dirname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inflateRawSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import {localTools} from './local_tools.mjs';

const tailwing = process.argv[2] === '--tailwing';
if (process.argv.length !== (tailwing ? 3 : 2)) throw new Error('invalid_arguments');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const relative = 'build/app/outputs/flutter-apk/app-release.apk';
const path = resolve(root, relative);
if (!realpathSync(path).startsWith(realpathSync(root) + sep) || lstatSync(path).size > 256 * 1024 ** 2) throw new Error('invalid_apk');
const data = readFileSync(path);
const sha256 = createHash('sha256').update(data).digest('hex');
const tools = localTools({android:true});
const sdk = tools.buildTools;
const java = resolve(tools.java, 'bin/java.exe');
function run(exe, args) {
  const r = spawnSync(exe, args, { encoding: 'utf8', windowsHide: true, maxBuffer: 4 * 1024 ** 2 });
  if (r.error) throw new Error('inspection_tool_unavailable');
  return { code: r.status, text: (r.stdout ?? '') + (r.stderr ?? '') };
}
const badging = run(`${sdk}/aapt2.exe`, ['dump', 'badging', path]);
const xml = run(`${sdk}/aapt2.exe`, ['dump', 'xmltree', '--file', 'AndroidManifest.xml', path]);
if (badging.code || xml.code) throw new Error('manifest_read_failed');
const pkg = /package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'/.exec(badging.text);
const target = Number(/targetSdkVersion:'(\d+)'/.exec(badging.text)?.[1]);
const min = Number(/(?:minSdkVersion|sdkVersion):'(\d+)'/.exec(badging.text)?.[1]);
if (!pkg || !Number.isInteger(target) || !Number.isInteger(min)) throw new Error('manifest_parse_failed');
function manifestFalse(name) {
  const line = xml.text.split('\n').find(s => s.includes(`android:${name}(`));
  return !!line && /(?:0x0|false)\s*$/.test(line.trim());
}
const debugLine = xml.text.split('\n').find(s => s.includes('android:debuggable('));
const permissions = [...badging.text.matchAll(/uses-permission: name='([^']+)'/g)].map(m => m[1]).sort();
const label = /application-label:'([^']+)'/.exec(badging.text)?.[1];
const signature = run(java, ['-jar', `${sdk}/lib/apksigner.jar`, 'verify', path]);
const signatureState = signature.code === 0 ? 'VERIFIED_SIGNATURE' :
  /Missing META-INF\/MANIFEST.MF|No signatures|does not verify/i.test(signature.text) ? 'UNSIGNED_NOT_INSTALLABLE_OR_SUBMITTABLE' : 'VERIFICATION_FAILED_REVIEW_REQUIRED';
const zip = run(`${sdk}/zipalign.exe`, ['-c', '-P', '16', '-v', '4', path]);

// Bounded standard ZIP, no extraction. Never emit found bytes or URLs.
let end = -1;
for (let i = data.length - 22; i >= Math.max(0, data.length - 65557); i--) {
  if (data.readUInt32LE(i) === 0x06054b50 && i + 22 + data.readUInt16LE(i + 20) === data.length) { end = i; break; }
}
if (end < 0 || data.readUInt16LE(end + 4) || data.readUInt16LE(end + 6)) throw new Error('unsupported_zip');
const count = data.readUInt16LE(end + 10);
let offset = data.readUInt32LE(end + 16), total = 0;
const matches = [], elf = [], names = new Set();
const patterns = [
  ['private_key', /-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----/],
  ['service_account_credential', /["']type["']\s*:\s*["']service_account["']/],
  ['literal_bearer_token', /Bearer\s+eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}/],
  ['oauth_refresh_token', /1\/\/[A-Za-z0-9_-]{60,}/],
  ['email_action_link_token', /[?&]oobCode=[A-Za-z0-9_-]{20,}/],
  ['isolated_test_marker', /IntegrationTestPlugin|dev\.flutter\.plugins\.integration_test|FixtureEntitlements|_PreviewLoadout|demo-airzero-strike|example\.test/],
];
for (let i = 0; i < count; i++) {
  if (data.readUInt32LE(offset) !== 0x02014b50) throw new Error('invalid_zip_directory');
  const flags = data.readUInt16LE(offset + 8), method = data.readUInt16LE(offset + 10);
  const compressed = data.readUInt32LE(offset + 20), size = data.readUInt32LE(offset + 24);
  const n = data.readUInt16LE(offset + 28), extra = data.readUInt16LE(offset + 30), comment = data.readUInt16LE(offset + 32);
  const local = data.readUInt32LE(offset + 42), name = data.subarray(offset + 46, offset + 46 + n).toString('utf8');
  if (names.has(name) || name.startsWith('/') || name.includes('..') || flags & 1 || size > 128 * 1024 ** 2) throw new Error('unsupported_zip_entry');
  names.add(name); total += size;
  if (total > 512 * 1024 ** 2 || data.readUInt32LE(local) !== 0x04034b50) throw new Error('zip_limit');
  const start = local + 30 + data.readUInt16LE(local + 26) + data.readUInt16LE(local + 28);
  const packed = data.subarray(start, start + compressed);
  if (packed.length !== compressed) throw new Error('truncated_zip_entry');
  const bytes = method === 0 ? packed : method === 8 ? inflateRawSync(packed, { maxOutputLength: 128 * 1024 ** 2 }) : null;
  if (!bytes || bytes.length !== size) throw new Error('unsupported_compression');
  const text = bytes.toString('latin1');
  for (const [type, pattern] of patterns) {
    if (pattern.test(text) || pattern.test(text.replaceAll('\0', ''))) matches.push({ entry: name, type });
  }
  if (/^lib\/(arm64-v8a|x86_64)\/[^/]+\.so$/.test(name)) {
    if (bytes.readUInt32BE(0) !== 0x7f454c46 || bytes[4] !== 2 || bytes[5] !== 1) throw new Error('unsupported_elf');
    const ph = Number(bytes.readBigUInt64LE(32)), step = bytes.readUInt16LE(54), num = bytes.readUInt16LE(56);
    let loads = 0, aligned = true;
    if (step < 56 || ph + step * num > bytes.length) throw new Error('invalid_elf_header');
    for (let j = 0; j < num; j++) {
      const p = ph + step * j;
      if (bytes.readUInt32LE(p) !== 1) continue;
      loads++;
      const fileOffset = bytes.readBigUInt64LE(p + 8), address = bytes.readBigUInt64LE(p + 16), align = bytes.readBigUInt64LE(p + 48);
      aligned &&= align >= 16384n && fileOffset % 16384n === address % 16384n;
    }
    elf.push({ entry: name, loadSegments: loads, aligned16KB: loads > 0 && aligned });
  }
  offset += 46 + n + extra + comment;
}
const checks = {
  existingAppId: pkg[1] === 'com.example.raikeopeu2026.dev',
  existingVersion: pkg[2] === '1' && pkg[3] === '0.1.0',
  expectedDisplayLabel: label === (tailwing ? '테일윙 · TAILWING' : 'AIRZERO STRIKE'),
  targetApi36OrHigher: target >= 36,
  backupDisabled: manifestFalse('allowBackup') && manifestFalse('fullBackupContent'),
  cleartextDisabled: manifestFalse('usesCleartextTraffic'),
  notDebuggable: !debugLine || /(?:0x0|false)\s*$/.test(debugLine.trim()),
  noBiometricPermissions: !permissions.some(p => /USE_BIOMETRIC|USE_FINGERPRINT/.test(p)),
  boundedPatternScan: matches.length === 0,
  zipAlignment16KB: zip.code === 0,
  elf64Alignment16KB: elf.length > 0 && elf.every(e => e.aligned16KB),
};
const report = { date: new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Seoul' }).format(new Date()), scope: 'LOCAL_UNSIGNED_APK_STATIC_INSPECTION_ONLY',
  path: relative, bytes: data.length, sha256, appId: pkg[1], displayLabel: label, versionCode: pkg[2], versionName: pkg[3],
  minSdk: min, targetSdk: target, permissions, signature: signatureState,
  entriesScanned: count, uncompressedBytes: total, patterns: patterns.map(([name]) => name), matches, elf64: elf, checks,
  status: Object.values(checks).every(Boolean) ? 'STATIC_CHECKS_PASS_SUBMISSION_BLOCKED' : 'STATIC_CHECK_FAILED',
  notChecked: ['signed_aab', 'install_and_runtime_of_this_apk', '16kb_device_runtime', 'real_auth_server_store',
    'all_secret_encodings_or_sdk_collection', 'ios_and_physical_devices'] };
writeFileSync(resolve(root, tailwing ? 'docs/tailwing/APK-INSPECTION.json' : 'docs/release-prep/APK-INSPECTION.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ status: report.status, signature: signatureState, entriesScanned: count, matches: matches.length, checks }));
if (report.status === 'STATIC_CHECK_FAILED' || signatureState === 'VERIFICATION_FAILED_REVIEW_REQUIRED') process.exitCode = 1;
