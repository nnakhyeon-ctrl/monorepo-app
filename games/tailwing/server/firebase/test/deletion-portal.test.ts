import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Script } from 'node:vm';
import { webcrypto } from 'node:crypto';
import { deletionPortal } from '../src/deletion-portal.js';

test('cloud portal has no enabled credential form, local endpoint or insecure script policy', () => {
  const page = deletionPortal(false);
  assert.doesNotMatch(page.html, /<script|type="password"|127\.0\.0\.1|id="commit"/);
  assert.equal(page.headers['Referrer-Policy'], 'no-referrer');
  assert.match(page.headers['Content-Security-Policy'], /frame-ancestors 'none'/);
  assert.doesNotMatch(page.headers['Content-Security-Policy'], /unsafe-inline|unsafe-eval/);
});

test('local portal script executes confirm/cancel/lost-response retry with memory-only credentials', async () => {
  const page = deletionPortal(true), code = /<script nonce="[^"]+">([\s\S]*?)<\/script>/.exec(page.html)?.[1];
  assert.ok(code);
  const elements: Record<string, any> = {};
  const element = (id: string) => elements[id] ??= { value: '', checked: false, hidden: false, disabled: false, textContent: '' };
  let loseCommit = false, commits = 0, resumptions = 0, preparedReceipt = '';
  const events: Record<string, () => void> = {};
  const fetch = async (url: string, options: { body: string; headers: Record<string, string> }) => {
    const body = JSON.parse(options.body);
    if (url.startsWith('http://127.0.0.1:9299/')) return { ok: true, json: async () => ({ idToken: 'synthetic-only' }) };
    assert.ok(url.startsWith('/demo/api/v1/'), 'same origin scoped API');
    if (url.endsWith('/session/start')) return { ok: true, json: async () => ({ sessionHandle: 'H'.repeat(43) }) };
    if (url.endsWith('/prepare')) {
      preparedReceipt = body.receipt; assert.match(preparedReceipt, /^[A-Za-z0-9_-]{43}$/);
      return { ok: true, json: async () => ({ status: 'prepared' }) };
    }
    if (url.endsWith('/commit')) {
      commits++; assert.equal(body.receipt, preparedReceipt); assert.equal(body.confirmed, true);
      if (loseCommit) throw new Error('synthetic lost response');
      return { ok: true, json: async () => ({ status: 'complete' }) };
    }
    if (url.endsWith('/resume')) {
      resumptions++; assert.equal(body.receipt, preparedReceipt);
      assert.equal(options.headers.Authorization, undefined, 'receipt cannot be used as an identity');
      return { ok: true, json: async () => ({ status: 'complete' }) };
    }
    throw new Error('unexpected test route');
  };
  new Script(code).runInNewContext({ document: { getElementById: element }, location: { pathname: '/demo/api/account-deletion' },
    crypto: webcrypto, Uint8Array, btoa: (s: string) => Buffer.from(s, 'binary').toString('base64'), fetch,
    addEventListener: (name: string, handler: () => void) => { events[name] = handler; } });
  element('email').value = 'fictional@example.test'; element('password').value = 'synthetic only';
  await element('prepare').onclick();
  assert.equal(element('password').value, ''); assert.equal(element('confirmation').hidden, false);
  await element('commit').onclick(); assert.equal(commits, 0, 'unchecked confirmation cannot commit');
  element('cancel').onclick(); await element('commit').onclick(); assert.equal(commits, 0);
  element('password').value = 'synthetic only'; await element('prepare').onclick();
  element('agree').checked = true; loseCommit = true;
  await element('commit').onclick(); assert.equal(commits, 1); assert.equal(element('resume').hidden, false);
  await element('resume').onclick(); assert.equal(resumptions, 1); assert.equal(element('resume').hidden, true);
  assert.match(element('status').textContent, /삭제를 완료/);
  element('password').value = 'must be cleared'; events.pagehide!(); assert.equal(element('password').value, '');
  assert.doesNotMatch(code, /localStorage|sessionStorage|console\.|document\.cookie|location\.search/);
});
