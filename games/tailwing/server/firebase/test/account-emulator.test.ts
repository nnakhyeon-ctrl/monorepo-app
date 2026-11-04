import { after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import type { AppCheck } from 'firebase-admin/app-check';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { AccountService, deletionNotice } from '../src/account.js';
import { AccountRepository, providerKey } from '../src/repository.js';
import { ApiError, demoProject, FirebaseSessionVerifier, loadConfig } from '../src/security.js';
import { sha256 } from '../src/social-proof.js';

// No credential fallback, remote endpoint or real Firebase project is possible.
if (process.env.GCLOUD_PROJECT !== demoProject || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9299' ||
    process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8280') throw new Error('local_demo_only');
const app = initializeApp({ projectId: demoProject }, 'account-management-fixtures');
const auth = getAuth(app), db = getFirestore(app);
const config = loadConfig({ ...process.env, FUNCTIONS_EMULATOR: 'true' });
let clock = Date.now(), sequence = 0, source = 0;
const now = () => clock;
const accounts = new AccountRepository(db, config, now);
const verifier = new FirebaseSessionVerifier(auth, {} as AppCheck, config, now,
  (uid, grant, time) => accounts.resolveSocialGrant(uid, grant, time));
const service = (checkpoint?: (step: string) => Promise<void>) =>
  new AccountService(config, auth, db, accounts, verifier, {}, now, checkpoint);
type Actor = { uid: string; token: string; handle: string };
async function actor(): Promise<Actor> {
  const uid = `account_fixture_${++sequence}`;
  const email = `${uid}@example.test`, password = 'Synthetic account test passphrase';
  await auth.createUser({ uid, email, password, emailVerified: true });
  const response = await fetch('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  assert.equal(response.status, 200, 'local synthetic identity');
  const result = await response.json() as { idToken: string };
  const session = await accounts.start(await verifier.verify(result.idToken));
  return { uid, token: result.idToken, handle: session.sessionHandle as string };
}
const ticket = () => randomBytes(32).toString('base64url');
const job = (receipt: string) => db.doc(`${accounts.scope}/deletionJobs/${sha256(receipt)}`);
const invoke = (s: AccountService, path: string, body: unknown = {}, a?: Actor, handle?: string) =>
  s.handle(path, body, a ? `Bearer ${a.token}` : undefined, undefined, handle ?? a?.handle, `account_source_${++source}`);
const prepare = (s: AccountService, a: Actor, receipt = ticket()) => invoke(s, 'prepare', { receipt }, a).then(() => receipt);
const commit = (s: AccountService, a: Actor, receipt: string) =>
  invoke(s, 'commit', { receipt, confirmed: true, noticeVersion: deletionNotice }, a);
const rejects = (action: Promise<unknown>, code?: string) => assert.rejects(action,
  (e: unknown) => e instanceof ApiError && (code === undefined || e.code === code));
beforeEach(() => { clock = Date.now(); });
after(async () => { await deleteApp(app); });

test('profile uses the verified owner/session; anonymous, expired and foreign handles are denied', async () => {
  const s = service(), a = await actor(), b = await actor();
  const profile = await invoke(s, 'profile', {}, a);
  assert.equal(profile.uid, a.uid); assert.deepEqual(profile.providers, ['password']);
  await rejects(invoke(s, 'profile'), 'invalid_session');
  await rejects(invoke(s, 'profile', {}, b, a.handle), 'invalid_session');
  clock += 3601000;
  await rejects(invoke(s, 'profile', {}, a), 'invalid_session');
});

test('reauth, explicit current notice and owner are required; cancellation/preparation deletes nothing', async () => {
  const s = service(), a = await actor(), b = await actor(), receipt = await prepare(s, a);
  assert.equal((await invoke(s, 'resume', { receipt })).status, 'prepared');
  assert.equal((await auth.getUser(a.uid)).disabled, false);
  assert.equal((await db.doc(`${accounts.scope}/accounts/${a.uid}`).get()).data()?.status, 'active');
  await rejects(commit(s, b, receipt), 'invalid_deletion_request');
  await rejects(invoke(s, 'prepare', { receipt: ticket(), uid: a.uid }, b), 'invalid_input');
  await rejects(invoke(s, 'commit', { receipt, confirmed: false, noticeVersion: deletionNotice }, a), 'confirmation_required');
  await rejects(invoke(s, 'commit', { receipt, confirmed: true, noticeVersion: 'old-notice' }, a), 'confirmation_required');
  clock += 301000;
  await rejects(invoke(s, 'prepare', { receipt: ticket() }, a), 'recent_authentication_required');
});

test('prepared request expiry and unknown/extra-field receipts never authorize a deletion', async () => {
  const s = service(), a = await actor(), receipt = await prepare(s, a);
  await job(receipt).update({ expiresAtMs: clock - 1 });
  await rejects(commit(s, a, receipt), 'deletion_request_expired');
  await rejects(invoke(s, 'resume', { receipt: ticket() }), 'deletion_request_expired');
  await rejects(invoke(s, 'resume', { receipt, uid: a.uid }), 'invalid_input');
  await rejects(invoke(s, 'resume', { receipt: 'short' }), 'invalid_deletion_request');
  assert.equal((await auth.getUser(a.uid)).disabled, false);
});

test('confirmed deletion removes own subtrees/Auth/mappings but preserves B and other app/environment', async () => {
  const s = service(), a = await actor(), b = await actor();
  const own = `${accounts.scope}/accounts/${a.uid}`;
  await db.doc(`${own}/private/progress`).set({ records: [{ stage: 1, best: 900 }] });
  await db.doc(`${own}/operations/nested/parts/deep`).set({ fixture: true });
  await db.doc(`${own}/private/entitlement_play`).set({ fixture: true });
  await db.doc(`${accounts.scope}/socialGrants/account_owned_grant`).set({ uid: a.uid });
  await db.doc(`${accounts.scope}/socialChallenges/account_owned_challenge`).set({ uid: a.uid });
  await db.doc(`${accounts.scope}/passwordAccounts/${a.uid}`).set({ origin: 'email-register' });
  const untouched = [ `${accounts.scope}/accounts/${b.uid}/private/progress`,
    `apps/other-app/environments/dev/accounts/${a.uid}/private/progress`,
    `apps/airzero-strike/environments/prod/accounts/${a.uid}/private/progress` ];
  for (const path of untouched) await db.doc(path).set({ marker: 'preserved' });
  const receipt = await prepare(s, a);
  assert.equal((await commit(s, a, receipt)).status, 'complete');
  assert.equal((await db.doc(own).get()).exists, false);
  assert.equal((await db.doc(`${own}/operations/nested/parts/deep`).get()).exists, false);
  for (const name of ['sessions', 'providers', 'socialGrants', 'socialChallenges']) {
    assert.equal((await db.collection(`${accounts.scope}/${name}`).where('uid', '==', a.uid).get()).empty, true);
  }
  assert.equal((await db.doc(`${accounts.scope}/passwordAccounts/${a.uid}`).get()).exists, false);
  await assert.rejects(auth.getUser(a.uid), (e: unknown) => (e as {code?: string}).code === 'auth/user-not-found');
  for (const path of untouched) assert.equal((await db.doc(path).get()).data()?.marker, 'preserved');
  assert.equal((await invoke(s, 'profile', {}, b)).uid, b.uid);
  await rejects(invoke(s, 'profile', {}, a), 'invalid_session');
  await rejects(invoke(s, 'prepare', { receipt: ticket() }, a), 'invalid_session');
  assert.equal((await invoke(s, 'resume', { receipt })).status, 'complete');
  const stored = (await job(receipt).get()).data()!;
  assert.equal('uid' in stored, false); assert.equal('receipt' in stored, false);
  assert.equal(stored.expiresAt instanceof Timestamp, true);
});

test('failure after disabling blocks access immediately and resumes without deleting another owner', async () => {
  const a = await actor(), b = await actor();
  let fail = true;
  const s = service(async step => { if (step === 'disabled' && fail) throw new Error('synthetic checkpoint'); });
  const receipt = await prepare(s, a);
  assert.equal((await commit(s, a, receipt)).status, 'pending');
  assert.equal((await auth.getUser(a.uid)).disabled, true);
  assert.equal((await job(receipt).get()).data()?.expiresAt, undefined, 'pending data has no TTL');
  await rejects(invoke(s, 'profile', {}, a), 'invalid_session');
  assert.equal((await invoke(s, 'profile', {}, b)).uid, b.uid);
  fail = false;
  assert.equal((await invoke(s, 'resume', { receipt })).status, 'complete');
  assert.equal((await auth.getUser(b.uid)).disabled, false);
});

test('expired receipt cannot read/continue publicly; maintenance still finishes retained pending data', async () => {
  const a = await actor();
  let fail = true;
  const s = service(async step => { if (step === 'data-removed' && fail) throw new Error('synthetic checkpoint'); });
  const receipt = await prepare(s, a);
  assert.equal((await commit(s, a, receipt)).status, 'pending');
  clock += 8 * 86400000;
  await rejects(invoke(s, 'resume', { receipt }), 'deletion_request_expired');
  fail = false; await s.maintenance();
  assert.equal((await job(receipt).get()).data()?.status, 'complete');
  await assert.rejects(auth.getUser(a.uid));
});

test('worker lease prevents concurrent cleanup and repeated completion is idempotent', async () => {
  const a = await actor();
  let release!: () => void, entered!: () => void, count = 0;
  const enteredPromise = new Promise<void>(r => { entered = r; });
  const hold = new Promise<void>(r => { release = r; });
  const s = service(async step => { if (step === 'disabled') { count++; entered(); await hold; } });
  const receipt = await prepare(s, a), deleting = commit(s, a, receipt);
  await enteredPromise;
  assert.equal((await invoke(s, 'resume', { receipt })).status, 'pending');
  release(); assert.equal((await deleting).status, 'complete');
  assert.equal((await invoke(s, 'resume', { receipt })).status, 'complete');
  assert.equal(count, 1);
});

test('tombstone prevents a late verified token from recreating a deleted application account', async () => {
  const a = await actor(), identity = await verifier.verify(a.token), s = service();
  const receipt = await prepare(s, a); await commit(s, a, receipt);
  await rejects(accounts.start(identity), 'account_unavailable');
  assert.equal((await db.doc(`${accounts.scope}/providers/${providerKey('password', a.uid)}`).get()).exists, false);
});

test('cloud deletion remains disabled without cleanup readiness and server secret; HTTP route is wired', async () => {
  const cloud = new AccountService({ ...config, mode: 'cloud' }, auth, db, accounts, verifier, {});
  assert.equal((await invoke(cloud, 'policy')).ready, false);
  await rejects(invoke(cloud, 'resume', { receipt: ticket() }), 'account_setup_required');
  const base = `http://127.0.0.1:5101/${demoProject}/asia-northeast3/api`;
  const policy = await fetch(`${base}/v1/public/account-policy`);
  assert.equal(policy.status, 200); assert.equal((await policy.json() as { ready: boolean }).ready, true);
  const unauthenticated = await fetch(`${base}/v1/account/deletion/prepare`, {
    method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ receipt: ticket() }),
  });
  assert.equal(unauthenticated.status, 401);
  const page = await fetch(`${base}/account-deletion`);
  assert.equal(page.status, 200); assert.equal(page.headers.get('referrer-policy'), 'no-referrer');
  assert.match(await page.text(), /AIRZERO STRIKE/);
});
