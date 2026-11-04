#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { root, child, privateName, bash, bashPath } from './lib/safety.mjs';

let failed = false;
const environment = {...process.env, CHECKPOINT_DISABLE:'1'};
for (const key of Object.keys(environment)) if (/^(BASH_ENV|ENV|SHELLOPTS|BASHOPTS|CDPATH|BASH_FUNC_.*)$/i.test(key)) delete environment[key];
function run(label, command, argv, quiet = false) {
  const result = spawnSync(command, argv, {cwd:root, env:environment, encoding:'utf8', timeout:120000, maxBuffer:1024*1024});
  if (result.error || result.status !== 0) {
    console.error('실패/실행 불가: ' + label);
    console.error(result.error?.message || (result.stdout || '') + (result.stderr || ''));
    failed = true;
  } else if (!quiet) {
    console.log('통과: ' + label);
    if (result.stdout?.trim()) console.log(result.stdout.trim());
  }
}
function walk(relative) {
  const result = [];
  for (const entry of fs.readdirSync(child(root, relative), {withFileTypes:true})) {
    if (['node_modules','build','DerivedData','.terraform'].includes(entry.name) || privateName.test(entry.name)) continue;
    const rel = relative + '/' + entry.name;
    child(root, rel);
    if (entry.isDirectory()) result.push(...walk(rel));
    else if (entry.isFile()) result.push(rel);
    else throw Error('검사 대상에 링크/특수 파일 있음');
  }
  return result;
}
run('문서 규칙', process.execPath, ['scripts/check-docs.mjs']);
run('민감정보·추적 파일', process.execPath, ['scripts/check-sensitive.mjs']);
const files = ['apps-deployment','infra','scripts','games/tailwing/tool'].flatMap(walk);
const js = files.filter(p => p.endsWith('.mjs'));
for (const p of js) run('JavaScript ' + p, process.execPath, ['--check',p], true);
console.log('JavaScript 문법 검사 대상: ' + js.length);
try {
  const executable = bash();
  const sh = [...files.filter(p => p.endsWith('.sh')), 'templates/app/deploy.config.example.sh'];
  for (const p of sh) run('Bash ' + p, executable, ['--noprofile','--norc','-n',bashPath(path.join(root,p))], true);
  console.log('Bash 문법 검사 대상: ' + sh.length);
} catch (error) { console.error(error.message); failed = true; }
const localTerraform = path.join(root, '.tools/terraform/1.9.8/terraform.exe');
const terraform = process.platform === 'win32' && fs.existsSync(localTerraform) ? localTerraform : 'terraform';
run('Terraform 포맷 (인프라 연결 없음)', terraform, ['fmt','-check','-recursive','infra/aws']);
run('생성기·경로·공개 파일·환경 검사 회귀 테스트', process.execPath, ['--test','scripts/tests/safety.test.mjs']);
run('게임 로컬 도구 경로·인증정보 비상속', process.execPath, ['--test','games/tailwing/tool/local_tools.test.mjs']);
run('출시 자료 소스 변경 감지·서명 파일 제외', process.execPath, ['--test','games/tailwing/tool/release_candidate.test.mjs']);
if (failed) process.exitCode = 1;
else console.log('전체 로컬 CI 통과');
