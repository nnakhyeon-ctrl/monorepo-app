import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { generate } from '../new-app.mjs';
import { build } from '../../infra/scripts/build-static-site.mjs';
import { root, child, bash, bashPath } from '../lib/safety.mjs';

function fixture(t) {
  const parent = child(root, '.test-tmp');
  fs.mkdirSync(parent, {recursive:true});
  const dir = fs.mkdtempSync(path.join(parent, 'safety-'));
  assert.ok(dir.startsWith(parent + path.sep));
  // 가상 문서만 만든다. Flutter 앱·계정·네트워크 작업은 없다.
  fs.cpSync(path.join(root, 'templates'), path.join(dir, 'templates'), {recursive:true});
  fs.mkdirSync(path.join(dir, 'apps-deployment'));
  fs.copyFileSync(path.join(root, 'apps-deployment/shared.config.sh'), path.join(dir, 'apps-deployment/shared.config.sh'));
  t.after(() => {
    assert.ok(path.resolve(dir).startsWith(path.resolve(parent) + path.sep));
    fs.rmSync(dir, {recursive:true,force:true});
  });
  return dir;
}
const valid = ['--name=sample-app','--platform=flutter','--category=utilities'];

test('Git은 비밀·실제 데이터·캡처·로컬 도구를 제외하고 앱 lockfile은 보존', () => {
  const excluded = ['.env','utilities/app/.env.production','secret.p8','key.properties','service-account-test.json','private/sample.json','data/sample.csv','captures/sample.png','screenshot-test.png','logs/sample.log','.tools/terraform/1.9.8/terraform.exe','.claude/settings.json','.codex/config.toml','flutter/bin/flutter.bat','games/tailwing/.flutter_tool_state'];
  const locks = ['utilities/app/pubspec.lock','apps-deployment/flutter/scripts/package-lock.json'];
  const output = execFileSync('git',['check-ignore','--stdin','-z'],{cwd:root,encoding:'utf8',input:[...excluded,...locks].join('\0') + '\0'}).split('\0').filter(Boolean);
  assert.deepEqual(output,excluded);
  // Local agent settings are deliberately untracked and absent in clean CI checkouts.
  // Validate a developer's optional file when present; its absence is already covered
  // by the required Git exclusion assertions above.
  const localSettings = path.join(root,'.claude/settings.json');
  if (fs.existsSync(localSettings)) JSON.parse(fs.readFileSync(localSettings,'utf8'));
});

test('경로·플랫폼·식별자·호스팅·중복 옵션을 쓰기 전에 거부', t => {
  const dir = fixture(t);
  for (const [key, value] of [['category','../escape'],['category','C:/escape'],['category','infra'],['name','con'],['platform','react-native'],['bundle-id','com.bad;code'],['hosting','unknown']]) {
    assert.throws(() => generate([...valid.filter(a => !a.startsWith('--' + key + '=')), '--' + key + '=' + value], dir));
  }
  assert.throws(() => generate([...valid,'--name=other'],dir));
  assert.equal(fs.existsSync(path.join(dir,'utilities')),false);
});

test('HTML·Bash 입력을 문자로 보존하고 force=false로 기존 문서를 보존', t => {
  const dir = fixture(t);
  const payload = "가상 '$(touch INJECTED)' & <img src=x onerror=alert(1)> $& = 테스트";
  const app = generate([...valid, '--display-name=' + payload, '--description=' + payload],dir);
  assert.equal(fs.existsSync(path.join(app,'pubspec.yaml')),false);
  const page = fs.readFileSync(path.join(app,'docs/index.html'),'utf8');
  assert.ok(page.includes('&lt;img'));
  assert.ok(!page.includes('<img'));
  assert.ok(page.includes('$&amp; = 테스트'));
  const environment = {PATH:process.env.PATH, SystemRoot:process.env.SystemRoot, HOME:dir, USERPROFILE:dir};
  const result = execFileSync(bash(), ['--noprofile','--norc','-c','source "$1"; printf "%s" "$ASC_APP_NAME"','test',bashPath(path.join(app,'deploy.config.sh'))],{cwd:app,encoding:'utf8',env:environment});
  assert.equal(result,payload);
  assert.equal(fs.existsSync(path.join(app,'INJECTED')),false);
  const before = fs.readFileSync(path.join(app,'README.md'),'utf8');
  assert.throws(() => generate([...valid,'--force=false'],dir));
  assert.equal(fs.readFileSync(path.join(app,'README.md'),'utf8'),before);
  generate([...valid,'--force=true'],dir);
});

test('ios·macos는 문서만 생성하고 앱별 공개 경로는 카테고리를 보존', t => {
  const dir = fixture(t);
  generate(['--name=same-name','--category=games','--platform=ios'],dir);
  generate(['--name=same-name','--category=utilities','--platform=macos'],dir);
  const result = build([],dir);
  assert.deepEqual(result.apps.sort(),['games/same-name','utilities/same-name']);
  assert.ok(fs.existsSync(path.join(result.out,'games/same-name/index.html')));
  assert.ok(fs.existsSync(path.join(result.out,'utilities/same-name/index.html')));
  build([],dir);
});

test('출력의 root·상위·절대·소스 경로와 사용자 파일 삭제를 차단', t => {
  const dir = fixture(t);
  generate(valid,dir);
  for (const out of ['.','..',dir,'templates','utilities/sample-app/docs','public-site/../templates','.env']) assert.throws(() => build(['--out=' + out],dir));
  const out = path.join(dir,'public-site');
  fs.mkdirSync(out);
  fs.writeFileSync(path.join(out,'keep.txt'),'가상 사용자 파일');
  assert.throws(() => build([],dir));
  assert.equal(fs.readFileSync(path.join(out,'keep.txt'),'utf8'),'가상 사용자 파일');
});

test('공개 docs의 비밀 파일과 데이터 파일을 거부하고 기존 출력 보존', t => {
  const dir = fixture(t);
  const app = generate(valid,dir);
  const result = build([],dir);
  const before = fs.readFileSync(path.join(result.out,'index.html'));
  for (const name of ['.env','dummy.p8','users.csv','private.json','capture.log']) {
    const target = path.join(app,'docs',name);
    fs.writeFileSync(target,'가상 데이터');
    // private.json은 확장자만으로 공개 허용하지 않고 이름으로 차단한다.
    assert.throws(() => build([],dir), name);
    fs.unlinkSync(target);
  }
  const target = path.join(app,'docs','public.json');
  fs.writeFileSync(target,JSON.stringify({type:['service','account'].join('_')}));
  assert.throws(() => build([],dir));
  assert.deepEqual(fs.readFileSync(path.join(result.out,'index.html')),before);
});

test('소유 표시가 있어도 추가·수정된 출력은 삭제하지 않음', t => {
  const dir = fixture(t);
  const result = build([],dir);
  fs.writeFileSync(path.join(result.out,'index.html'),'사용자 수정');
  assert.throws(() => build([],dir));
  assert.equal(fs.readFileSync(path.join(result.out,'index.html'),'utf8'),'사용자 수정');
});

test('junction을 통한 앱 쓰기·공개 복사를 차단하고 링크 대상 보존', t => {
  const dir = fixture(t);
  const outside = path.join(dir,'outside');
  fs.mkdirSync(outside);
  fs.mkdirSync(path.join(dir,'utilities'));
  const link = path.join(dir,'utilities','sample-app');
  fs.symlinkSync(outside,link,process.platform === 'win32' ? 'junction' : 'dir');
  try {
    assert.throws(() => generate([...valid,'--force=true'],dir));
    assert.throws(() => build([],dir));
    assert.deepEqual(fs.readdirSync(outside),[]);
  } finally { fs.unlinkSync(link); }
});

test('check-env는 기본 실행에서 config를 source하지 않으며 명시적 로드는 상태만 출력', t => {
  const dir = fixture(t);
  const app = generate(valid,dir);
  fs.mkdirSync(path.join(dir,'scripts/lib'),{recursive:true});
  for (const file of ['check-env.mjs','lib/safety.mjs']) fs.copyFileSync(path.join(root,'scripts',file),path.join(dir,'scripts',file));
  const config = path.join(app,'deploy.config.sh');
  fs.writeFileSync(config,'touch EXECUTED\nexport PLAY_PACKAGE_NAME="com.example.fake"\nexport PLAY_SA_KEY="fake-file.json"\n');
  fs.writeFileSync(path.join(app,'fake-file.json'),'{}');
  const argv = [path.join(dir,'scripts/check-env.mjs'),'--app=utilities/sample-app','--platform=android'];
  const environment = {PATH:process.env.PATH, SystemRoot:process.env.SystemRoot, ProgramFiles:process.env.ProgramFiles, HOME:dir, USERPROFILE:dir};
  const dry = spawnSync(process.execPath,argv,{encoding:'utf8',env:environment});
  assert.equal(dry.status,0,dry.stderr);
  assert.equal(fs.existsSync(path.join(app,'EXECUTED')),false);
  const loaded = spawnSync(process.execPath,[...argv,'--load-reviewed-config'],{encoding:'utf8',env:environment});
  assert.equal(loaded.status,0,loaded.stderr);
  assert.equal(fs.existsSync(path.join(app,'EXECUTED')),true);
  assert.ok(!loaded.stdout.includes('com.example.fake'));
  assert.ok(!loaded.stdout.includes('fake-file.json'));
});
