#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { root, args, appPath, child, bash, bashPath } from './lib/safety.mjs';

// 이 검사는 개발 도구 검사가 아니다. 실제 배포 키는 2단계에 필요 없다.
try {
  const a = args(process.argv.slice(2), ['app','platform','load-reviewed-config'], ['load-reviewed-config']);
  if (!a.app) throw Error('--app=category/app 경로가 필요합니다. 2단계에는 실제 앱 설정 검사가 해당되지 않습니다.');
  const dir = appPath(root, a.app);
  const platform = a.platform || 'flutter';
  if (!['flutter','ios','macos','android'].includes(platform)) throw Error('지원하지 않는 플랫폼');
  const config = child(root, a.app + '/deploy.config.sh');
  if (!fs.existsSync(config)) throw Error('앱 설정 파일 없음');
  console.log('대상: ' + a.app);
  if (!a['load-reviewed-config']) {
    console.log('설정 파일 존재 확인. 실행하지 않았습니다. 설정과 모든 source 대상을 검토한 뒤에만 --load-reviewed-config를 사용하세요.');
    console.log('배포 환경변수·키 파일 검사는 미실행입니다.');
  } else {
    const ios = platform !== 'android';
    const play = ['flutter','android'].includes(platform);
    const names = [...(ios ? ['ASC_API_KEY','ASC_API_ISSUER','ASC_TEAM_ID','ASC_BUNDLE_ID','ASC_APP_NAME'] : []), ...(play ? ['PLAY_PACKAGE_NAME','PLAY_SA_KEY'] : [])];
    // 파일명은 argv로 전달한다. 로그인 프로필을 실행하지 않으며 env 전체를 출력하지 않는다.
    const script = [
      'set -e',
      'source "$1" >/dev/null 2>&1',
      'shift',
      'for name in "$@"; do',
      '  if [[ -n "\${!name:-}" ]]; then printf "%s=set\\n" "$name"; else printf "%s=missing\\n" "$name"; fi',
      'done',
      'if [[ -n "\${ASC_API_KEY:-}" ]]; then',
      '  key="\${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_\${ASC_API_KEY}.p8}"',
      '  if [[ -f "$key" ]]; then echo "ASC_KEY_FILE=set"; else echo "ASC_KEY_FILE=missing"; fi',
      'fi',
      'if [[ -n "\${PLAY_SA_KEY:-}" ]]; then',
      '  if [[ -f "$PLAY_SA_KEY" ]]; then echo "PLAY_KEY_FILE=set"; else echo "PLAY_KEY_FILE=missing"; fi',
      'fi'
    ].join('\n');
    const environment = {...process.env};
    for (const key of Object.keys(environment)) if (/^(BASH_ENV|ENV|SHELLOPTS|BASHOPTS|CDPATH|BASH_FUNC_.*)$/i.test(key)) delete environment[key];
    let raw;
    try { raw = execFileSync(bash(), ['--noprofile','--norc','-c', script, 'check-env', bashPath(config), ...names], {cwd:dir, env:environment, encoding:'utf8', stdio:['ignore','pipe','pipe'], maxBuffer:64*1024, timeout:10000}); }
    catch { throw Error('검토된 설정 로드 실패 (민감한 하위 출력은 숨김)'); }
    const statuses = new Map(raw.trim().split('\n').map(line => line.split('=')));
    const expected = [...names, ...(ios ? ['ASC_KEY_FILE'] : []), ...(play ? ['PLAY_KEY_FILE'] : [])];
    let failed = false;
    for (const name of expected) {
      const ok = statuses.get(name) === 'set';
      console.log(name + ': ' + (ok ? '설정됨/존재' : '누락'));
      failed ||= !ok;
    }
    if (failed) process.exitCode = 1;
  }
} catch (error) { console.error(error.message); process.exitCode = 2; }
