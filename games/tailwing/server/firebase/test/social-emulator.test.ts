import { beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import type { AppCheck } from 'firebase-admin/app-check';
import { getFirestore } from 'firebase-admin/firestore';
import { ApiError, demoProject, FirebaseSessionVerifier, loadConfig } from '../src/security.js';
import { AccountRepository, providerKey } from '../src/repository.js';
import { SocialService } from '../src/social.js';
import { config, signingFixture } from './social-fixtures.js';
import type { SocialProvider } from '../src/social-proof.js';

if (process.env.GCLOUD_PROJECT !== demoProject || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9299' ||
  process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8280') throw new Error('local_demo_only');
const app = initializeApp({ projectId: demoProject }, 'social-fixtures');
const auth = getAuth(app), db = getFirestore(app);
const runtime = loadConfig({ ...process.env, FUNCTIONS_EMULATOR: 'true' });
const accounts = new AccountRepository(db, runtime);
const sessions = new FirebaseSessionVerifier(auth, {} as AppCheck, runtime, Date.now,
  (uid, grant, time) => accounts.resolveSocialGrant(uid, grant, time));
const f = await signingFixture();
const service = new SocialService(runtime, config, auth, db, accounts, sessions, f.verifier, undefined);
let source = 0;
const invoke = (path: string, body: unknown, token?: string, handle?: string) =>
  service.handle(path, body, token ? `Bearer ${token}` : undefined, undefined, handle, `synthetic_source_${source}`);
const begin = (provider: SocialProvider = 'google', intent = 'signin', token?: string, handle?: string) =>
  invoke('begin', { provider, intent }, token, handle) as Promise<{ challengeId: string; state: string; nonce: string }>;
async function complete(c: Awaited<ReturnType<typeof begin>>, provider: SocialProvider = 'google', token?: string, handle?: string, overrides = {}) {
  return invoke('complete', { challengeId: c.challengeId, state: c.state, proof: {
    kind: `${provider}-id-token`, idToken: await f.token(provider, c.nonce, overrides),
    ...(provider === 'kakao' ? { accessToken: 'opaque-synthetic-access' } : {}),
  } }, token, handle) as Promise<{ uid: string; customToken: string; linked: boolean }>;
}
async function exchange(customToken: string) {
  const response = await fetch('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=demo-api-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token: customToken, returnSecureToken: true }) });
  const result = await response.json() as { idToken: string };
  assert.equal(response.status, 200, 'local custom token exchange');
  return result.idToken;
}
async function emailOwner(suffix: string) {
  const user = await auth.createUser({ email: `social_${suffix}@example.test`, password: 'Synthetic email owner phrase 2026', emailVerified: true });
  const response = await fetch('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: user.email, password: 'Synthetic email owner phrase 2026', returnSecureToken: true }) });
  const { idToken } = await response.json() as { idToken: string };
  const identity = await sessions.verify(idToken);
  const started = await accounts.start(identity);
  return { uid: user.uid, token: idToken, handle: started.sessionHandle as string };
}
beforeEach(() => { source++; });
after(async () => { await deleteApp(app); });

test('social reauth refreshes only an already linked subject and never creates a new account/link', async () => {
  const owner = await emailOwner('account_reauth');
  const linked = await begin('google', 'link', owner.token, owner.handle);
  await complete(linked, 'google', owner.token, owner.handle, { sub: 'account_reauth_subject' });
  // Move only the server/provider fixture clock. Rewriting auth_time would make
  // a token predate the user's revocation timestamp and test a revoked token,
  // rather than a valid old session. Production verification remains intact.
  const future = () => Date.now() + 301000;
  const laterAccounts = new AccountRepository(db, runtime, future);
  const laterSessions = new FirebaseSessionVerifier(auth, {} as AppCheck, runtime, future,
    (uid, grant, time) => laterAccounts.resolveSocialGrant(uid, grant, time));
  const laterProof = await signingFixture(future);
  const later = new SocialService(runtime, config, auth, db, laterAccounts, laterSessions, laterProof.verifier, undefined, future);
  const invokeLater = (path: string, body: unknown) => later.handle(path, body, `Bearer ${owner.token}`, undefined, owner.handle, 'synthetic_account_reauth');
  await assert.rejects(invokeLater('begin', { provider: 'google', intent: 'link' }), (e: unknown) => e instanceof ApiError && e.code === 'recent_authentication_required');
  const challenge = await invokeLater('begin', { provider: 'google', intent: 'reauth' }) as { challengeId: string; state: string; nonce: string };
  const completeLater = async (subject: string) => invokeLater('complete', { challengeId: challenge.challengeId, state: challenge.state,
    proof: { kind: 'google-id-token', idToken: await laterProof.token('google', challenge.nonce, { sub: subject }) } });
  await assert.rejects(completeLater('unlinked_reauth_subject'),
    (e: unknown) => e instanceof ApiError && e.code === 'provider_conflict');
  const refreshed = await completeLater('account_reauth_subject');
  assert.equal(refreshed.uid, owner.uid);
  assert.equal(typeof refreshed.customToken, 'string');
  assert.equal(refreshed.linked, false);
  assert.equal((await db.doc(`${accounts.scope}/providers/${providerKey('google.com', 'unlinked_reauth_subject')}`).get()).exists, false);
});

test('unconfigured service denies social login and no raw or unbound custom token is a private session', async () => {
  const base = `http://127.0.0.1:5101/${demoProject}/asia-northeast3/api`;
  const policy = await fetch(`${base}/v1/public/social-policy`);
  assert.equal(policy.status, 200);
  assert.deepEqual(await policy.json(), { enabled: [] });
  const unavailable = await fetch(`${base}/v1/social/begin`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ provider: 'google', intent: 'signin' }) });
  assert.equal(unavailable.status, 503);
  const disabled = new SocialService(runtime, {}, auth, db, accounts, sessions, f.verifier, undefined);
  assert.deepEqual(await disabled.handle('policy', {}, undefined, undefined, undefined, 'synthetic_policy'), { enabled: [] });
  await assert.rejects(disabled.handle('begin', { provider: 'google', intent: 'signin' }, undefined, undefined, undefined, 'synthetic_policy'), ApiError);
  await assert.rejects(sessions.verify(await f.token('google', 'synthetic_nonce')), ApiError);
  const unbound = await auth.createCustomToken('synthetic_unbound');
  await assert.rejects(sessions.verify(await exchange(unbound)), ApiError);
});
test('concurrent first sign-ins use one UID; no email forces signup or joins an existing email account', async () => {
  const existing = await emailOwner('separate');
  const first = await begin(), second = await begin();
  const [a, b] = await Promise.all([complete(first, 'google', undefined, undefined, { sub: 'concurrent_subject', email: 'social_separate@example.test' }),
    complete(second, 'google', undefined, undefined, { sub: 'concurrent_subject' })]);
  assert.equal(a.uid, b.uid);
  assert.notEqual(a.uid, existing.uid);
  assert.equal((await auth.getUser(a.uid)).email, undefined);
  const identity = await sessions.verify(await exchange(a.customToken));
  const started = await accounts.start(identity);
  assert.equal(started.uid, a.uid);
  assert.equal((await accounts.read(identity, started.sessionHandle as string, 'progress')).records instanceof Array, true);
  await assert.rejects(accounts.read(await sessions.verify(existing.token), started.sessionHandle as string, 'progress'), ApiError);
  const sdkToken = await exchange(b.customToken);
  const response = await fetch(`http://127.0.0.1:5101/${demoProject}/asia-northeast3/api/v1/session/start`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${sdkToken}` }, body: '{}' });
  assert.equal(response.status, 200, 'deployed local handler accepts verified app grant');
});
test('explicit recent email link preserves UID and records; conflicting provider keeps both accounts', async () => {
  const owner = await emailOwner('link');
  const record = db.doc(`${accounts.scope}/accounts/${owner.uid}/private/progress`);
  await record.set({ generation: 0, records: [{ stage: 1, cleared: true, best: 999, attempts: 1 }], unlocked: 2, revision: 1 });
  const saved = (await record.get()).data();
  const c = await begin('kakao', 'link', owner.token, owner.handle);
  const result = await complete(c, 'kakao', owner.token, owner.handle);
  assert.equal(result.uid, owner.uid);
  assert.equal(result.linked, true);
  assert.equal((await sessions.verify(await exchange(result.customToken))).uid, owner.uid);
  assert.deepEqual((await record.get()).data(), saved);
  const other = await emailOwner('other');
  const conflict = await begin('kakao', 'link', other.token, other.handle);
  await assert.rejects(complete(conflict, 'kakao', other.token, other.handle), (e: unknown) => e instanceof ApiError && e.code === 'provider_conflict');
  assert.equal((await db.doc(`${accounts.scope}/providers/${providerKey('kakao', '123456')}`).get()).data()?.uid, owner.uid);
  assert.deepEqual((await record.get()).data(), saved);
  await assert.rejects(begin('google', 'link'), ApiError);
  await assert.rejects(begin('google', 'link', owner.token, other.handle), ApiError);
  const future = () => Date.now() + 301000;
  const oldSessions = new FirebaseSessionVerifier(auth, {} as AppCheck, runtime, future,
    (uid, grant, time) => accounts.resolveSocialGrant(uid, grant, time));
  const later = new SocialService(runtime, config, auth, db, accounts, oldSessions, f.verifier, undefined, future);
  await assert.rejects(later.handle('begin', { provider: 'google', intent: 'link' }, `Bearer ${owner.token}`,
    undefined, owner.handle, 'synthetic_old_auth'), (e: unknown) => e instanceof ApiError && e.code === 'recent_authentication_required');
});
test('state, challenge expiry/reuse, different owner and nonce mismatch fail closed', async () => {
  const c = await begin();
  await assert.rejects(invoke('complete', { challengeId: c.challengeId, state: 'z'.repeat(43), proof: {} }), ApiError);
  await assert.rejects(complete(c, 'google', undefined, undefined, { nonce: 'wrong_nonce' }), ApiError);
  await complete(c, 'google', undefined, undefined, { sub: 'one_use_subject' });
  await assert.rejects(complete(c), ApiError);
  const expired = await begin();
  await db.doc(`${accounts.scope}/socialChallenges/${expired.challengeId}`).update({ expiresAtMs: 0 });
  await assert.rejects(complete(expired), ApiError);
  const a = await emailOwner('state_a'), b = await emailOwner('state_b');
  const link = await begin('google', 'link', a.token, a.handle);
  await assert.rejects(complete(link, 'google', b.token, b.handle), ApiError);
});
test('grant expiry, auth revocation, disabled user and deleted mapping block access', async () => {
  const c = await begin();
  const result = await complete(c, 'google', undefined, undefined, { sub: 'revoked_subject' });
  const token = await exchange(result.customToken);
  const decoded = await auth.verifyIdToken(token);
  assert.equal((await sessions.verify(token)).uid, result.uid);
  await db.doc(`${accounts.scope}/socialGrants/${decoded.azSocialGrant}`).update({ expiresAtMs: 0 });
  await assert.rejects(sessions.verify(token), ApiError);
  const next = await complete(await begin(), 'google', undefined, undefined, { sub: 'revoked_subject' });
  const nextToken = await exchange(next.customToken);
  await accounts.invalidateAuthSessions(result.uid);
  await assert.rejects(sessions.verify(nextToken), ApiError);
  const third = await complete(await begin(), 'google', undefined, undefined, { sub: 'revoked_subject' });
  const thirdToken = await exchange(third.customToken);
  await auth.updateUser(result.uid, { disabled: true });
  await assert.rejects(sessions.verify(thirdToken), ApiError);
  await assert.rejects(complete(await begin(), 'google', undefined, undefined, { sub: 'revoked_subject' }), ApiError);
  await auth.updateUser(result.uid, { disabled: false });
  await db.doc(`${accounts.scope}/providers/${providerKey('google.com', 'revoked_subject')}`).delete();
  await assert.rejects(sessions.verify(thirdToken), ApiError);
  await auth.deleteUser(result.uid);
  // Keep the established mapping: deleted Auth users must not be re-created.
  await db.doc(`${accounts.scope}/providers/${providerKey('google.com', 'revoked_subject')}`).set({
    uid: result.uid, provider: 'google.com', subject: 'revoked_subject', provisioning: false });
  await assert.rejects(complete(await begin(), 'google', undefined, undefined, { sub: 'revoked_subject' }), ApiError);
});
