import { randomBytes } from 'node:crypto';

/** Local proof of the external (no app reinstall) request path. No cloud login
 * form is enabled until a dedicated web Auth/App Check deployment is verified. */
export function deletionPortal(local: boolean) {
  const nonce = randomBytes(24).toString('base64url');
  const headers = {
    'Content-Security-Policy': `default-src 'none'; script-src 'nonce-${nonce}'; style-src 'nonce-${nonce}'; connect-src 'self'${local ? ' http://127.0.0.1:9299' : ''}; base-uri 'none'; frame-ancestors 'none'; form-action 'none'`,
    'Referrer-Policy': 'no-referrer', 'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
    'X-Frame-Options': 'DENY',
  };
  const html = `<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer">
<title>AIRZERO STRIKE 계정 삭제 요청</title><style nonce="${nonce}">body{font:18px/1.6 system-ui;background:#091724;color:#e7f6ff;max-width:42rem;margin:2rem auto;padding:1rem}input,button{font:inherit;padding:.7rem;box-sizing:border-box;max-width:100%}label{display:block;margin:1rem 0}input{display:block;width:100%}button{margin:.4rem 0}section{border:1px solid #55becd;padding:1rem;margin:1rem 0}[hidden]{display:none}a{color:#72e2ed}#status{white-space:pre-wrap}</style>
<h1>AIRZERO STRIKE 계정 삭제</h1><p>개발자: 케일 · 앱을 재설치하지 않고 이 앱의 계정·게임 기록 삭제를 요청하는 경로입니다.</p>
<section><h2>삭제 전 확인</h2><p>이 계정의 서버 진행·클리어·최고점수·개인 설정·로그인 연결·세션을 삭제하며 복구할 수 없습니다. 다른 앱, 카카오·Google·Apple 자체 계정과 기기의 게스트 원본은 삭제하지 않습니다. 다른 기기에 남은 오프라인 캐시는 다음 인증에서 접근이 차단됩니다.</p>
<p>구독 해지·자동 갱신 중지·환불은 별도입니다. 구독 중이어도 즉시 삭제를 선택할 수 있습니다.</p><p><a href="https://play.google.com/store/account/subscriptions" rel="noreferrer">Google Play 구독 관리</a> · <a href="https://apps.apple.com/account/subscriptions" rel="noreferrer">Apple 구독 관리</a></p>
<p>정상 연결 시 즉시 처리하고, 장애 시 완료 확인을 재시도합니다. 요청 확인값·접근 차단 해시는 최대 7일 보관하며, 미완료 작업은 완료될 때까지 보관합니다. 결제는 아직 미연결입니다. 실제 구매 기록 보관 예외·기간은 결제 도입 전 확정합니다.</p></section>
${local ? `<h2>로컬 가상 계정 전용</h2><p>demo 에뮬레이터에서 만든 @example.test 이메일만 사용합니다. 실제 사용자 계정·메일·소셜 로그인은 처리하지 않습니다.</p>
<label>가상 이메일<input id="email" type="email" autocomplete="username" maxlength="254"></label><label>가상 계정 비밀번호<input id="password" type="password" autocomplete="current-password" maxlength="4096"></label>
<label><input id="show" type="checkbox">비밀번호 표시</label><button id="prepare">본인 확인 · 삭제 준비</button>
<section id="confirmation" hidden><p>본인 확인을 마쳤습니다. 아직 삭제하지 않았습니다.</p><label><input id="agree" type="checkbox">위 삭제 범위·복구 불가·구독 별도 안내를 확인했습니다.</label><button id="commit">이 계정 즉시 삭제 요청</button><button id="cancel">취소 · 기록 유지</button></section>
<button id="resume" hidden>접수·삭제 완료 확인 다시 시도</button>` : '<h2>실제 외부 삭제 접수는 연결 준비 중입니다</h2><p>개발 서버와 전용 웹 인증·App Check·허용 도메인·HTTPS 공개 주소를 아직 연결하지 않았습니다. 이 화면에서 실제 삭제를 접수했다고 표시하지 않습니다. 공개 전 이메일·소셜 계정 모두 재설치 없이 본인 확인·요청할 수 있도록 실연동 검증이 필요합니다.</p>'}
<p id="status" role="status" aria-live="polite"></p>
${local ? `<script nonce="${nonce}">
(() => { 'use strict';
const el = id => document.getElementById(id), base = location.pathname.slice(0, -'/account-deletion'.length);
let token = '', session = '', receipt = '', pending = false, busy = false;
const say = text => { el('status').textContent = text; };
const lock = value => { busy = value; for (const id of ['prepare','commit','cancel','resume']) el(id).disabled = value; };
const call = async (path, body, authenticated = false) => {
  const response = await fetch(base + path, {method:'POST',cache:'no-store',referrerPolicy:'no-referrer',redirect:'error',headers:{'Content-Type':'application/json',...(authenticated ? {Authorization:'Bearer ' + token,'X-Airzero-Session':session} : {})},body:JSON.stringify(body)});
  const value = await response.json(); if (!response.ok) throw new Error('request_failed'); return value;
};
const check = result => {
  if (result.status === 'complete') { token = ''; session = ''; receipt = ''; pending = false; el('resume').hidden = true; say('AIRZERO STRIKE의 계정·서버 기록 삭제를 완료했습니다. 구독 해지와 공급자 자체 계정은 별도입니다.'); }
  else if (result.status === 'prepared') { pending = false; receipt = ''; el('resume').hidden = true; say('삭제는 접수되지 않았습니다. 본인 확인부터 다시 진행해 주세요.'); }
  else { say('처리 중입니다. 완료를 다시 확인해 주세요.'); }
};
el('show').onchange = () => { el('password').type = el('show').checked ? 'text' : 'password'; };
el('prepare').onclick = async () => {
 if (busy || pending) return; lock(true);
 try {
  el('confirmation').hidden = true; receipt = ''; token = ''; session = '';
  const email = el('email').value.trim(), password = el('password').value; el('password').value = '';
  if (!/^[^\\s@]+@example\\.test$/.test(email)) throw new Error('local_only');
  const response = await fetch('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo', {method:'POST',cache:'no-store',referrerPolicy:'no-referrer',redirect:'error',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});
  const identity = await response.json(); if (!response.ok || !identity.idToken) throw new Error('identity'); token = identity.idToken;
  const started = await call('/v1/session/start', {}, true); session = started.sessionHandle;
  const bytes = crypto.getRandomValues(new Uint8Array(32)); receipt = btoa(String.fromCharCode(...bytes)).replace(/\\+/g,'-').replace(/\\//g,'_').replace(/=/g,'');
  await call('/v1/account/deletion/prepare', {receipt}, true); el('agree').checked = false; el('confirmation').hidden = false; say('본인 확인 완료. 최종 요청 전에는 삭제하지 않습니다.');
 } catch (_) { token = ''; session = ''; receipt = ''; say('본인 확인 또는 연결에 실패했습니다. 이메일·비밀번호·이메일 확인 상태를 확인하고 다시 시도해 주세요.'); }
 finally { lock(false); }
};
el('cancel').onclick = () => { token = ''; session = ''; receipt = ''; el('confirmation').hidden = true; say('탈퇴를 취소했습니다. 계정과 기록은 유지했습니다.'); };
el('commit').onclick = async () => {
 if (busy || !receipt || !el('agree').checked) { say('삭제 범위 확인에 직접 동의해 주세요.'); return; } lock(true); pending = true; el('confirmation').hidden = true; el('resume').hidden = false;
 try { check(await call('/v1/account/deletion/commit', {receipt,confirmed:true,noticeVersion:'airzero-account-delete-v1'}, true)); }
 catch (_) { say('접수·완료 여부를 확인하지 못했습니다. 완료 확인을 다시 시도해 주세요.'); }
 finally { token = ''; session = ''; lock(false); }
};
el('resume').onclick = async () => { if (busy || !receipt) return; lock(true); try { check(await call('/v1/account/deletion/resume',{receipt})); } catch (_) { say('처리 확인에 실패했습니다. 다시 시도해 주세요.'); } finally { lock(false); } };
addEventListener('pagehide', () => { token = ''; session = ''; receipt = ''; el('password').value = ''; });
})();</script>` : ''}</html>`;
  return { headers, html };
}
