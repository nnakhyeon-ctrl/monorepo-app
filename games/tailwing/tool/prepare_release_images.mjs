import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const only = process.argv[2] === '--screenshots-only';
if (process.argv.length > (only ? 3 : 2)) throw new Error('invalid_arguments');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const folder = 'docs/release-prep/graphics';
const jobs = [];
function add(source, target, width, height, alpha = false) {
  jobs.push({ source: resolve(root, source), target: resolve(root, target), width, height, alpha });
}
if (!only) {
  const icon = `${folder}/icon-source-v1.png`;
  add(icon, `${folder}/play-icon-512.png`, 512, 512, true);
  add(icon, `${folder}/ios-icon-1024.png`, 1024, 1024);
  add(`${folder}/feature-source-v1.png`, `${folder}/play-feature-1024x500.png`, 1024, 500);
  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    add(icon, `android/app/src/main/res/mipmap-${density}/ic_launcher.png`, size, size, true);
  }
  const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const contents = JSON.parse(readFileSync(resolve(root, dir, 'Contents.json')));
  for (const image of contents.images) {
    if (!image.filename) continue;
    if (!/^Icon-App-[A-Za-z0-9.@-]+\.png$/.test(image.filename)) throw new Error('unexpected_icon_filename');
    const size = Number(image.size.split('x')[0]) * Number(image.scale.replace('x', ''));
    add(icon, `${dir}/${image.filename}`, size, size);
  }
}
for (const name of ['01-home','02-stage1','03-free-shield','04-stage1-flight']) {
  const source = `docs/release-prep/screenshots/android/raw/${name}.png`;
  if (existsSync(resolve(root, source))) add(source, `docs/release-prep/screenshots/android/${name}.png`, 1080, 1920);
}
const local = resolve(root, 'server/firebase/.runtime');
mkdirSync(local, { recursive: true });
const exe = resolve(local, 'release-image-helper.exe');
const csc = 'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe';
execFileSync(csc, ['/nologo', '/reference:System.Drawing.dll', '/reference:System.Web.Extensions.dll',
  `/out:${exe}`, resolve(root, 'tool/ReleaseImageHelper.cs')], { windowsHide: true, stdio: 'pipe' });
const plan = resolve(local, 'release-image-plan.json');
writeFileSync(plan, JSON.stringify({ root, jobs }));
execFileSync(exe, [plan], { windowsHide: true, stdio: 'inherit' });
console.log(`Converted ${jobs.length} app-local image assets; no signing, store or cloud action.`);
