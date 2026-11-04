// Verify saved local artifacts, not store/server readiness. No network or secrets.
import { readFileSync, existsSync, writeFileSync } from 'node:fs';
import { resolve, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { inspectBillingSetup } from './check_billing_readiness.mjs';
if (process.argv.length !== 2) throw new Error('no_arguments_accepted');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = p => readFileSync(resolve(root, p));
const json = p => JSON.parse(read(p).toString('utf8'));
const sha = b => createHash('sha256').update(b).digest('hex');
const checks = [];
function check(id, condition) { checks.push({ id, status:condition ? 'PASS' : 'FAIL' }); }
const inventory = json('docs/release-prep/ASSET-INVENTORY.json');
check('all_saved_asset_hashes_match', inventory.files.every(f => existsSync(resolve(root, f.path)) && sha(read(f.path)) === f.sha256));
check('all_saved_asset_sizes_match', inventory.files.every(f => read(f.path).length === f.bytes));
function png(path, width, height, color) {
  const b = read(path);
  return b.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) &&
    b.readUInt32BE(16) === width && b.readUInt32BE(20) === height && b[24] === 8 && b[25] === color;
}
check('play_icon_format_size', png('docs/release-prep/graphics/play-icon-512.png',512,512,6) && read('docs/release-prep/graphics/play-icon-512.png').length <= 1024 ** 2);
check('play_feature_rgb', png('docs/release-prep/graphics/play-feature-1024x500.png',1024,500,2));
check('ios_icon_rgb', png('docs/release-prep/graphics/ios-icon-1024.png',1024,1024,2));
const names = ['01-home','02-stage1','03-free-shield','04-stage1-flight'];
check('four_android_screenshots_rgb_9_16', names.every(n => png(`docs/release-prep/screenshots/android/${n}.png`,1080,1920,2)));
check('five_native_android_icon_sizes', Object.entries({mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192}).every(([d,s]) => png(`android/app/src/main/res/mipmap-${d}/ic_launcher.png`,s,s,6)));
const ios = json('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').images.filter(i => i.filename);
check('native_ios_icons_contents_match', ios.length === 19 && new Set(ios.map(i => i.filename)).size === 15 && ios.every(i => {
  const s = Number(i.size.split('x')[0]) * Number(i.scale.replace('x',''));
  return png(`ios/Runner/Assets.xcassets/AppIcon.appiconset/${i.filename}`,s,s,2);
}));
const artifact = json('docs/release-prep/APK-INSPECTION.json');
check('inspection_apk_hash_matches', sha(read(artifact.path)) === artifact.sha256 && artifact.sha256 === inventory.inspectionBuild.sha256);
check('inspection_static_checks_pass', artifact.status === 'STATIC_CHECKS_PASS_SUBMISSION_BLOCKED' && Object.values(artifact.checks).every(Boolean));
check('unsigned_submission_block_preserved', artifact.signature === 'UNSIGNED_NOT_INSTALLABLE_OR_SUBMITTABLE' && !inventory.signedAabProduced && !inventory.ipaProduced);
const snapshot = json('docs/release-prep/SOURCE-SNAPSHOT.json');
check('mobile_source_snapshot_matches', snapshot.files.every(f => sha(read(f.path)) === f.sha256));
const billing = inspectBillingSetup(root);
check('purchase_lock_and_pending_config_preserved', inventory.purchaseLocked && billing.liveVerification === 'NOT_RUN' &&
  billing.localStatus === 'PENDING' && billing.checks.some(c => c.id === 'purchase_activation' && c.code === 'purchase_remains_disabled'));
const docs = ['docs/STAGE12-PREPARATION.md','docs/STAGE12-CHECKPOINT.md','docs/EXTERNAL-SETUP-ORDER.md',
  'docs/release-prep/STORE-COPY.md','docs/release-prep/STORE-CHECKLIST.md','docs/release-prep/ASSET-REVIEW.md'];
let links = 0, broken = 0;
for (const p of docs) {
  for (const m of read(p).toString('utf8').matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
    const target = m[1].replace(/^<|>$/g,'').split('#')[0];
    if (!target || /^https?:/.test(target)) continue;
    links++;
    if (!existsSync(resolve(dirname(resolve(root,p)), decodeURIComponent(target)))) broken++;
  }
}
const pages = inventory.files.filter(f => extname(f.path) === '.html');
let pageLinks = 0;
check('local_html_no_forms_scripts_remote_resources', pages.length === 5 && pages.every(f => {
  const s = read(f.path).toString('utf8');
  return s.includes('noindex,nofollow') && s.includes('no-referrer') && s.includes("form-action 'none'") &&
    !/<(?:script|form|input|iframe|object|embed)\b/i.test(s) && !/(?:src|action)\s*=\s*["']https?:/i.test(s);
}));
for (const f of pages) {
  for (const m of read(f.path).toString('utf8').matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (/^https?:/.test(m[1])) continue;
    pageLinks++;
    if (!existsSync(resolve(dirname(resolve(root,f.path)), m[1]))) broken++;
  }
}
check('document_and_local_page_links_exist', broken === 0);
check('saved_status_not_submission_ready', inventory.status === 'LOCAL_PREPARATION_RECORDED_NOT_SUBMISSION_READY');
const report = {date:'2026-10-29',scope:'LOCAL_MATERIAL_VERIFICATION_ONLY',
  status:checks.every(c => c.status === 'PASS') ? 'PASS_NOT_SUBMISSION_READY' : 'FAIL',
  checks, checkedDocumentLinks:links, checkedLocalHtmlLinks:pageLinks,
  notChecked:['browser_screenreader_rendering','native_launcher_masks','signed_aab_ipa','real_server_login_store', 'ios_physical_16kb_devices']};
writeFileSync(resolve(root,'docs/release-prep/MATERIAL-CHECKS.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status:report.status,passed:checks.filter(c => c.status === 'PASS').length,total:checks.length,brokenLinks:broken}));
if (report.status === 'FAIL') process.exitCode = 1;
