// Local review material only. Fixed allowlisted sources, no server or deployment.
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, lstatSync, realpathSync } from 'node:fs';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
if (process.argv.length !== 2) throw new Error('no_arguments_accepted');
const root = realpathSync(resolve(dirname(fileURLToPath(import.meta.url)), '..'));
function local(path) {
  const full = resolve(root, path);
  if (!full.startsWith(root + sep)) throw new Error('outside_app');
  let p = root;
  for (const part of full.slice(root.length + 1).split(sep)) {
    p = resolve(p, part);
    if (existsSync(p) && lstatSync(p).isSymbolicLink()) throw new Error('symlink_not_allowed');
  }
  return full;
}
const output = 'docs/release-prep/local-pages';
mkdirSync(local(output), { recursive: true });
const esc = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
function inline(s) {
  return esc(s).replace(/\[([^\]]+)\]\((https:\/\/[^\s)]+)\)/g, '<a href="$2" rel="noreferrer noopener">$1</a>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/`([^`]+)`/g, '<code>$1</code>');
}
function markdown(s) {
  // Deliberately small subset; never execute embedded HTML or fetch resources.
  return s.trim().split(/\r?\n\s*\r?\n/).map(block => {
    const h = /^(#{1,3}) (.+)$/.exec(block);
    return h ? `<h${h[1].length}>${inline(h[2])}</h${h[1].length}>` : `<p>${inline(block).replaceAll('\n', '<br>')}</p>`;
  }).join('\n');
}
function page(title, body) {
  return `<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex,nofollow"><meta name="referrer" content="no-referrer"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; base-uri 'none'; form-action 'none'"><title>${esc(title)} | AIRZERO STRIKE local review</title><style>body{margin:0;background:#09151f;color:#e0edf1;font:17px/1.7 system-ui,sans-serif}main{max-width:920px;margin:auto;padding:24px}a{color:#65ded0;overflow-wrap:anywhere}code{overflow-wrap:anywhere}.notice{padding:16px;border:2px solid #e8b662;background:#30261b}img{max-width:100%;height:auto}.icon{width:144px}.circle{clip-path:circle(50%)}.rounded{border-radius:25%}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:20px}figure{margin:0}h1{font-size:1.6em}h2{margin-top:1.7em}p{overflow-wrap:anywhere}</style></head><body><main><p class="notice">비공개 로컬 검토본 · 제출/서비스 제공 준비 미완료 · 공개 주소/접수 기능 없음</p><nav><a href="index.html">자료 목록</a></nav>${body}<footer><p>2026-10-29 검토 스냅샷. 문의/로그인/삭제 폼·스크립트·분석·외부 글꼴 없음. 실제 공개에는 내용 확정·서버 보안 헤더·인증/삭제 구현과 검증이 필요합니다.</p></footer></main></body></html>\n`;
}
for (const name of ['support', 'privacy', 'delete-account', 'terms']) {
  writeFileSync(local(`${output}/${name}.html`), page(name, markdown(readFileSync(local(`docs/pages/${name}.md`), 'utf8'))));
}
const shots = ['01-home','02-stage1','03-free-shield','04-stage1-flight'];
writeFileSync(local(`${output}/index.html`), page('출시 자료 검토', `<h1>AIRZERO STRIKE 출시 자료 검토</h1><p>가상 Android 앱의 실제 Flutter 무료 플레이 화면입니다. 실기기·iOS·스토어 검증 자료가 아닙니다. 아래 아이콘 마스크는 CSS 미리보기이며 실제 런처 검사와 다릅니다.</p><p>${['support','privacy','delete-account','terms'].map(n => `<a href="${n}.html">${n}</a>`).join(' · ')}</p><h2>브랜드 후보</h2><p><img class="icon" src="../graphics/play-icon-512.png" alt="사각 아이콘 후보"> <img class="icon circle" src="../graphics/play-icon-512.png" alt="원형 마스크 미리보기"> <img class="icon rounded" src="../graphics/play-icon-512.png" alt="모서리 마스크 미리보기"></p><p>날개 끝이 원형에서 잘릴 수 있습니다. Android 적응형/테마 아이콘·실제 런처 및 Xcode 검토는 대기입니다. 배너는 AI 제작 브랜드 그림으로 실제 플레이 화면과 구분합니다.</p><img src="../graphics/play-feature-1024x500.png" alt="AIRZERO STRIKE 해안 전투기 브랜드 배너"><h2>실제 게임 프레임</h2><div class="gallery">${shots.map(n => `<figure><img src="../screenshots/android/${n}.png" alt="${n} 실제 무료 게임 프레임"><figcaption>${n} · 1080×1920 · RGB</figcaption></figure>`).join('')}</div>`));

const source = [];
function collect(path) {
  const stat = lstatSync(local(path));
  if (stat.isDirectory()) {
    for (const name of readdirSync(local(path)).sort()) collect(`${path}/${name}`);
  } else if (stat.isFile()) {
    if (stat.size > 32 * 1024 ** 2) throw new Error('source_size_limit');
    const bytes = readFileSync(local(path));
    source.push({ path, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') });
  }
}
// No .env, credentials, config/.local-public, SDK cache, build, logs or user data.
for (const path of ['lib','assets','pubspec.yaml','pubspec.lock','android/app/src/main',
  'android/app/build.gradle.kts','android/build.gradle.kts','android/settings.gradle.kts',
  'android/gradle.properties','android/gradle/wrapper/gradle-wrapper.properties',
  'ios/Runner/Assets.xcassets','ios/Runner/Info.plist','ios/Runner/AppDelegate.swift',
  'ios/Runner/Runner.entitlements','ios/Runner.xcodeproj/project.pbxproj']) {
  if (existsSync(local(path))) collect(path);
}
source.sort((a,b) => a.path.localeCompare(b.path, 'en'));
const head = spawnSync('git', ['rev-parse', '--verify', 'HEAD'], { cwd: root, encoding:'utf8', windowsHide:true });
const tracked = spawnSync('git', ['ls-files', '--', 'lib', 'assets', 'pubspec.yaml', 'pubspec.lock', 'android', 'ios'], { cwd:root, encoding:'utf8', windowsHide:true });
const fingerprint = createHash('sha256').update(source.map(f => `${f.path}\0${f.sha256}\n`).join('')).digest('hex');
writeFileSync(local('docs/release-prep/SOURCE-SNAPSHOT.json'), JSON.stringify({
  date:'2026-10-29', scope:'ALLOWLISTED_MOBILE_SOURCE_AFTER_BUILD_NOT_PROOF_OF_BUILD_PROVENANCE',
  gitHead:head.status === 0 ? head.stdout.trim() : null,
  gitStatus:tracked.status === 0 && !tracked.stdout.trim() ? 'ALLOWLISTED_APP_SOURCE_UNTRACKED' : 'TRACKED_SOURCE_REQUIRES_STATUS_REVIEW', fileCount:source.length, fingerprint, files:source,
  excludes:['server','test','integration_test','docs','tool','config/.local-public','local auth xcconfig', 'secrets', 'user data', 'build and SDK caches'],
}, null, 2) + '\n');
const files = [];
for (const path of ['docs/release-prep/graphics','docs/release-prep/screenshots/android',output]) {
  function walk(folder) {
    for (const name of readdirSync(local(folder)).sort()) {
      const p = `${folder}/${name}`, s = lstatSync(local(p));
      if (s.isDirectory()) walk(p);
      else if (s.isFile() && /\.(png|html)$/.test(name)) {
        const b = readFileSync(local(p));
        files.push({ path:p, bytes:b.length, sha256:createHash('sha256').update(b).digest('hex'),
          ...(/\.png$/.test(name) ? { width:b.readUInt32BE(16), height:b.readUInt32BE(20), colorType:b[25] } : {}) });
      }
    }
  }
  walk(path);
}
const inspection = JSON.parse(readFileSync(local('docs/release-prep/APK-INSPECTION.json'), 'utf8'));
writeFileSync(local('docs/release-prep/ASSET-INVENTORY.json'), JSON.stringify({date:'2026-10-29',
  status:'LOCAL_PREPARATION_RECORDED_NOT_SUBMISSION_READY', version:'0.1.0+1', appId:'com.example.raikeopeu2026.dev',
  purchaseLocked:true, signedAabProduced:false, ipaProduced:false, files,
  inspectionBuild:{path:inspection.path,bytes:inspection.bytes,sha256:inspection.sha256,signature:inspection.signature},
  mobileSourceFingerprint:fingerprint,
}, null, 2) + '\n');
console.log(JSON.stringify({ localPages:5, assets:files.length, mobileSourceFiles:source.length, status:'NOT_SUBMISSION_READY' }));
