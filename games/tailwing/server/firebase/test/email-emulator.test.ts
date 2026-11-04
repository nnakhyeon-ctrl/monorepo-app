import { beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { demoProject } from '../src/security.js';
import { MailLimiter, newPassword } from '../src/email.js';

if (process.env.GCLOUD_PROJECT !== demoProject || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9299' ||
  process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8280') throw new Error('local_demo_only');
const app = initializeApp({ projectId: demoProject }, 'email-fixtures');
const auth = getAuth(app), db = getFirestore(app);
const scope = 'apps/airzero-strike/environments/dev';
const base = `http://127.0.0.1:5101/${demoProject}/asia-northeast3/api`;
const oldPassword = 'Synthetic email fixture passphrase 2026';
const nextPassword = 'New synthetic email fixture passphrase 2026';
type Actor = { uid: string; token: string; email: string; handle?: string };
async function call(path: string, body: unknown = {}, actor?: Actor, method = 'POST') {
  const r = await fetch(base + path, { method, headers: { 'Content-Type': 'application/json',
    ...(actor ? { Authorization: `Bearer ${actor.token}`, ...(actor.handle ? { 'X-Airzero-Session': actor.handle } : {}) } : {}) },
    ...(method === 'GET' ? {} : { body: JSON.stringify(body) }) });
  return { status: r.status, body: await r.json() as Record<string, any> };
}
async function signIn(email: string, password = oldPassword): Promise<Actor> {
  const r = await fetch('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, returnSecureToken: true }) });
  const data = await r.json() as Record<string, any>;
  assert.equal(r.status, 200, 'local Firebase password sign-in');
  return { uid: data.localId, token: data.idToken, email };
}
async function codes(email: string, mode: string) {
  const r = await fetch(`http://127.0.0.1:9299/emulator/v1/projects/${demoProject}/oobCodes`);
  const result = await r.json() as { oobCodes: { email: string; requestType: string; oobCode: string; oobLink: string }[] };
  return result.oobCodes.filter((c) => c.email === email && c.requestType === mode);
}
async function register(email: string) {
  const r = await call('/v1/auth/register', { email, password: oldPassword, consent: true });
  assert.equal(r.status, 200, 'email register request');
  assert.deepEqual(r.body, { accepted: true, retryAfterSeconds: 60 });
  return signIn(email);
}
beforeEach(async () => {
  // Isolate independent examples; the rate-limit test does not clear its own counters.
  const docs = await db.collection(`${scope}/emailLimits`).get();
  await Promise.all(docs.docs.map((d) => d.ref.delete()));
});
after(async () => { await deleteApp(app); });

test('email registration, unverified denial, verification, reset, old-session denial and new-password sign-in', async () => {
  const email = 'stage7_flow@example.test';
  const a = await register(email);
  assert.equal((await call('/v1/session/start', {}, a)).status, 403);
  const verify = (await codes(email, 'VERIFY_EMAIL')).at(-1)!;
  assert.ok(verify, 'local mail captured without printing links');
  const action = { mode: 'verifyEmail', code: verify.oobCode };
  assert.equal((await call('/v1/auth/check-action', action, a)).status, 200);
  assert.equal((await call('/v1/auth/confirm-action', action, a)).status, 200);
  assert.equal((await call('/v1/auth/confirm-action', action, a)).status, 400);
  const verified = await signIn(email);
  const session = await call('/v1/session/start', {}, verified);
  assert.equal(session.status, 200);
  verified.handle = session.body.sessionHandle;
  await call('/v1/auth/reset-email', { email });
  const reset = (await codes(email, 'PASSWORD_RESET')).at(-1)!;
  const check = { mode: 'resetPassword', code: reset.oobCode };
  assert.equal((await call('/v1/auth/check-action', check)).status, 200);
  assert.equal((await call('/v1/auth/confirm-action', { ...check, password: nextPassword })).status, 200);
  assert.equal((await call('/v1/auth/confirm-action', { ...check, password: nextPassword })).status, 400);
  assert.equal((await call('/v1/me/progress', {}, verified, 'GET')).status, 401);
  const fresh = await signIn(email, nextPassword);
  assert.equal((await call('/v1/me/progress', {}, { ...fresh, handle: verified.handle }, 'GET')).status, 401);
  assert.equal((await call('/v1/session/start', {}, fresh)).status, 200);
});

test('duplicate/unknown reset requests keep the same response shape and response floor', async () => {
  const email = 'stage7_duplicate@example.test';
  await register(email);
  const begin = Date.now();
  const duplicate = await call('/v1/auth/register', { email, password: oldPassword, consent: true });
  assert.ok(Date.now() - begin >= 750, 'response floor');
  assert.equal(duplicate.status, 200);
  const existing = await call('/v1/auth/reset-email', { email });
  const unknown = await call('/v1/auth/reset-email', { email: 'stage7_absent@example.test' });
  assert.equal(existing.status, unknown.status);
  assert.deepEqual(existing.body, unknown.body);
  const count = (await codes(email, 'PASSWORD_RESET')).length;
  assert.deepEqual((await call('/v1/auth/reset-email', { email })).body, existing.body);
  assert.equal((await codes(email, 'PASSWORD_RESET')).length, count, 'cooldown does not send twice');
  assert.equal((await call('/v1/auth/reset-email', { email, continueUrl: 'https://other.invalid' })).status, 400);
});

test('another account cannot consume verification/change links and email change needs recent password authentication', async () => {
  const a = await register('stage7_change_a@example.test');
  const b = await register('stage7_change_b@example.test');
  const link = (await codes(a.email, 'VERIFY_EMAIL')).at(-1)!;
  const proof = { mode: 'verifyEmail', code: link.oobCode };
  assert.equal((await call('/v1/auth/check-action', proof, b)).status, 403);
  assert.equal((await call('/v1/auth/confirm-action', proof, a)).status, 200);
  const verified = await signIn(a.email);
  assert.equal((await call('/v1/auth/change-email', { email: 'stage7_changed@example.test' }, verified)).status, 200);
  const change = (await codes(a.email, 'VERIFY_AND_CHANGE_EMAIL')).at(-1)!;
  assert.ok(change, 'email change captured');
  const action = { mode: 'verifyAndChangeEmail', code: change.oobCode };
  assert.equal((await call('/v1/auth/check-action', action, b)).status, 403);
  assert.equal((await call('/v1/auth/confirm-action', action, verified)).status, 200);
  const updated = await signIn('stage7_changed@example.test');
  assert.equal(updated.uid, a.uid);
});

test('mail limits are shared server-side by source/account with bounded cooldown and unknown tokens are rejected', async () => {
  let now = 1000;
  const limiter = new MailLimiter(db, scope, 'synthetic-only-unit-rate-secret', () => now);
  assert.equal(await limiter.allow('fictional_source_a', 'fictional_account', 'send'), true);
  assert.equal(await limiter.allow('fictional_source_b', 'fictional_account', 'send'), false);
  now += 60001;
  assert.equal(await limiter.allow('fictional_source_b', 'fictional_account', 'send'), true);
  for (let i = 0; i < 20; i++) await limiter.allow('fictional_source_c', `fictional_${i}`, 'send');
  await assert.rejects(limiter.allow('fictional_source_c', 'fictional_extra', 'send'));
  now += 900001;
  assert.equal(await limiter.allow('fictional_source_c', 'fictional_extra', 'send'), true);
  assert.equal((await call('/v1/auth/check-action', { mode: 'verifyEmail', code: 'not_a_valid_code_0000' })).status, 400);
  assert.equal((await call('/v1/auth/confirm-action', { mode: 'resetPassword', code: 'not_a_valid_code_0000', password: nextPassword })).status, 400);
});

test('password policy blocks known/common values without forcing composition or storing account passwords in Firestore', () => {
  assert.throws(() => newPassword('12345678901234567890'));
  assert.throws(() => newPassword('short'));
  assert.equal(newPassword('a fictional long phrase without digit'), 'a fictional long phrase without digit');
});

test('unapproved social password additions cannot request reset mail or open private game data', async () => {
  // Admin-created, local-only provider fixtures; no social login is enabled.
  const email = 'stage7_social_fixture@example.test';
  const user = await auth.createUser({ email, password: oldPassword, emailVerified: true });
  await auth.updateUser(user.uid, { providerToLink: { providerId: 'google.com', uid: 'fictional_google_subject', email } });
  const actor = await signIn(email);
  const denied = await call('/v1/session/start', {}, actor);
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, 'password_link_required');
  assert.deepEqual((await call('/v1/auth/reset-email', { email })).body,
    { accepted: true, retryAfterSeconds: 60 });
  assert.equal((await codes(email, 'PASSWORD_RESET')).length, 0);
  // A provider-generated reset cannot bypass the app's linking boundary.
  const link = new URL(await auth.generatePasswordResetLink(email));
  const action = { mode: 'resetPassword', code: link.searchParams.get('oobCode'), password: nextPassword };
  assert.equal((await call('/v1/auth/confirm-action', action)).status, 400);
  const original = await signIn(email);
  assert.equal(original.uid, user.uid);
});
