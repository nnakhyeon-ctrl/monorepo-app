#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { root, args, slug, reserved, appPath, child, html, shell, text } from './lib/safety.mjs';

const options = ['help','name','platform','category','bundle-id','display-name','description','constraints','hosting','company','support-email','force'];
export function generate(argv, base = root) {
  const a = args(argv, options, ['help','force']);
  if (a.help) {
    console.log('문서·설정 7개 생성: --name=my-app --platform=flutter|ios|macos --category=utilities\n선택: --bundle-id=com.example.myapp --display-name=이름 --description=설명 --constraints=제약 --hosting=undecided|netlify|vercel|aws --company=회사 --support-email=support@example.com --force=true|false\n앱 소스 생성·설치·빌드·배포는 수행하지 않습니다.');
    return;
  }
  const name = slug(a.name, 'name');
  const category = slug(a.category, 'category');
  if (reserved.has(category)) throw Error('예약된 카테고리');
  if (!['flutter','ios','macos'].includes(a.platform)) throw Error('platform은 flutter, ios, macos 중 하나');
  const hosting = a.hosting || 'undecided';
  if (!['netlify','vercel','aws','undecided'].includes(hosting)) throw Error('허용되지 않는 hosting');
  const bundle = a['bundle-id'] || 'com.example.' + name.replaceAll('-', '');
  if (!/^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*){2,}$/.test(bundle) || bundle.length > 150) throw Error('식별자는 소문자 reverse-DNS 형식이어야 합니다.');
  const display = text(a['display-name'] || name, 'display-name', 100);
  const description = text(a.description || '앱의 목적과 핵심 사용자를 작성하세요.', 'description');
  const constraints = text(a.constraints || '지원 OS와 기기 제약을 작성하세요.', 'constraints');
  const company = text(a.company || 'Example Company', 'company', 100);
  const email = a['support-email'] || 'support@example.com';
  if (!/^[a-z0-9.!#$%&'*+/=?^_\x60{|}~-]+@[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}$/i.test(email) || email.length > 254) throw Error('잘못된 이메일 형식');
  const relative = category + '/' + name;
  const dir = appPath(base, relative);
  if (fs.existsSync(dir) && !fs.statSync(dir).isDirectory()) throw Error('앱 경로가 폴더가 아님');
  if (fs.existsSync(dir) && fs.readdirSync(dir).length && !a.force) throw Error('비어 있지 않은 앱 폴더: 명시적인 --force=true 필요');
  const template = p => fs.readFileSync(child(base, p), 'utf8');
  const values = {
    APP_NAME_DISPLAY:html(display), APP_NAME_EN:html(display), TAGLINE:html(description),
    DESCRIPTION_HTML:'<p>' + html(description) + '</p>\n    <p>지원 환경: ' + html(constraints) + '</p>',
    COPYRIGHT_YEAR:String(new Date().getFullYear()), COMPANY_NAME:html(company),
    LAST_UPDATED:new Date().toISOString().slice(0,10),
    PRIVACY_SUMMARY:'실제 데이터 수집·로그인·결제 설계가 확정된 뒤 작성합니다. 현재는 템플릿입니다.',
    SUPPORT_EMAIL:html(email)
  };
  const replace = (source, replacements) => source.replace(/\{\{([A-Z_]+)\}\}/g, (match, key) => replacements[key] ?? match);
  // Markdown에서도 사용자 입력을 raw HTML로 해석하지 않도록 escape한다.
  const md = value => html(value).replace(/([\\\x60*_[\]{}])/g, '\\$1');
  const readme = [
    '# ' + md(display), '', md(description), '',
    '## 앱 경계', '',
    '- 플랫폼: ' + a.platform, '- 식별자: ' + bundle, '- 지원 환경: ' + md(constraints),
    '- 호스팅: ' + hosting, '- 경로: ' + relative, '',
    '## 의존성과 빌드', '',
    '현재 문서와 설정만 생성됐습니다. 실제 앱 소스·pubspec.yaml·pubspec.lock은 아직 없습니다.',
    '다음 단계에서 앱 생성 후 앱 폴더에서 flutter pub get / flutter analyze / flutter test를 실행합니다.',
    'Android 빌드는 앱 폴더에서 flutter build apk --debug를 사용합니다. iOS 빌드는 Mac/Xcode가 필요합니다.',
    '공통 코드·의존성은 실제 재사용 범위가 확인된 뒤 분리합니다. 스토어 작업은 사용자가 직접 합니다.',
    '', 'ROADMAP.md와 AGENTS.md를 먼저 확인합니다.', ''
  ].join('\n');
  const appValues = { APP_NAME:md(display), PLATFORM:a.platform, BUNDLE_ID:bundle, CONSTRAINTS:md(constraints), HOSTING:hosting, DESCRIPTION:md(description) };
  const cfg = [
    '# 검토 후에만 Bash로 source합니다. 비밀 값은 저장소 밖에서 관리합니다.',
    'APPS_DEPLOY_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")/../../apps-deployment" && pwd)"',
    'export APPS_DEPLOY_DIR', 'source "$APPS_DEPLOY_DIR/shared.config.sh"', '',
    'export ASC_BUNDLE_ID=' + shell(bundle), 'export ASC_APP_NAME=' + shell(display),
    'export PLAY_PACKAGE_NAME=' + shell(bundle), ''
  ].join('\n');
  const files = [
    ['README.md', readme],
    ['AGENTS.md', replace(template('templates/app/AGENTS.md'), appValues)],
    ['CLAUDE.md', template('templates/app/CLAUDE.md')],
    ['ROADMAP.md', replace(template('templates/app/ROADMAP.md'), appValues)],
    ['deploy.config.sh', cfg],
    ['docs/index.html', replace(template('templates/docs/index.html'), values)],
    ['docs/privacy.html', replace(template('templates/docs/privacy.html'), values)]
  ];
  // 전체 대상과 기존 파일을 확인한 뒤 쓰기 시작한다.
  const planned = files.map(([p, content]) => [child(base, relative + '/' + p), content]);
  for (const [p] of planned) {
    if (fs.existsSync(p) && (!a.force || !fs.statSync(p).isFile())) throw Error('기존 파일 덮어쓰기 거부');
    child(base, path.relative(base, path.dirname(p)).replaceAll('\\','/'));
  }
  fs.mkdirSync(dir, {recursive:true});
  for (const [p, content] of planned) {
    fs.mkdirSync(path.dirname(p), {recursive:true});
    fs.writeFileSync(p, content.endsWith('\n') ? content : content + '\n', {flag:a.force ? 'w' : 'wx'});
  }
  console.log('문서·설정 생성 완료: ' + relative + ' (앱 소스는 별도 단계)');
  return dir;
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try { generate(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode = 2; }
}
