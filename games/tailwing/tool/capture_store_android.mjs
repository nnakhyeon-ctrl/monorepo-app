// Dedicated emulator only. No account, purchase, real user file or cloud API.
import { spawn, execFileSync } from 'node:child_process';
import { createInterface } from 'node:readline';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.argv.length !== 2) throw new Error('no_arguments_supported');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const adb = 'C:\\Users\\user\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe';
const device = ['-s', 'emulator-5554'];
const packageName = 'com.example.raikeopeu2026.dev.integration';
function command(args, options = {}) {
  return execFileSync(adb, [...device, ...args], {
    windowsHide: true, timeout: 20000, maxBuffer: 12 * 1024 * 1024,
    ...options,
  });
}
if (command(['shell', 'getprop', 'ro.kernel.qemu'], { encoding: 'utf8' }).trim() !== '1') {
  throw new Error('dedicated_emulator_required');
}
const names = ['01-home', '02-stage1', '03-free-shield', '04-stage1-flight'];
const out = resolve(root, 'docs/release-prep/screenshots/android/raw');
const local = resolve(root, 'server/firebase/.runtime/native-local');
mkdirSync(out, { recursive: true });
mkdirSync(local, { recursive: true });
const env = Object.fromEntries(['PATH', 'Path', 'PATHEXT', 'SystemRoot', 'SYSTEMROOT',
  'WINDIR', 'windir', 'COMSPEC', 'ComSpec', 'TEMP', 'TMP']
  .filter(k => process.env[k] !== undefined).map(k => [k, process.env[k]]));
Object.assign(env, {
  USERPROFILE: 'C:\\Users\\user', HOMEDRIVE: 'C:', HOMEPATH: '\\Users\\user',
  LOCALAPPDATA: local,
  ANDROID_HOME: 'C:\\Users\\user\\AppData\\Local\\Android\\Sdk',
  JAVA_HOME: 'C:\\Program Files\\Android\\Android Studio\\jbr', CI: 'true',
});
let code = 1;
try {
  command(['shell', 'wm', 'size', '1080x1920']);
  const script = "& 'C:\\Users\\user\\flutter\\bin\\flutter.bat' --suppress-analytics test integration_test/store_capture_test.dart -d emulator-5554 --dart-define=AIRZERO_INTEGRATION=true --no-uninstall --reporter expanded; exit $LASTEXITCODE";
  const child = spawn('powershell.exe', ['-NoProfile', '-Command', script], {
    cwd: root, env, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
  });
  for (const stream of [child.stdout, child.stderr]) createInterface({ input: stream }).on('line', line => {
    if (/https?:\/\/|oobCode|idToken|refreshToken|Bearer |@example\.|apiKey=/i.test(line)) return;
    process.stdout.write(line + '\n');
  });
  code = await new Promise(res => {
    child.on('error', () => res(1));
    child.on('close', n => res(n ?? 1));
  });
  if (code === 0) {
    for (const name of names) {
      const bytes = command(['exec-out', 'run-as', packageName, 'cat',
        `files/airzero_stage12_capture_v1/${name}.png`]);
      if (bytes.length < 24 || bytes.toString('hex', 0, 8) !== '89504e470d0a1a0a' ||
          bytes.readUInt32BE(16) !== 1080 || bytes.readUInt32BE(20) !== 1920) {
        throw new Error('capture_format_invalid');
      }
      writeFileSync(resolve(out, `${name}.png`), bytes);
    }
    console.log('STAGE12_CAPTURE: four real Flutter frames; fictional free guest; 1080x1920; not iOS/release/device certification');
  }
} finally {
  command(['shell', 'wm', 'size', 'reset']);
}
process.exitCode = code;
