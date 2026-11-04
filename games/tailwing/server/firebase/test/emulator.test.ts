import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { demoProject } from '../src/security.js';
import { defaultPreferences } from '../src/validation.js';

if (process.env.GCLOUD_PROJECT !== demoProject || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8280' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9299') throw new Error('local_demo_only');
const app = initializeApp({ projectId: demoProject }, 'airzero-security-fixtures');
const db = getFirestore(app), auth = getAuth(app);
const scope = 'apps/airzero-strike/environments/dev';
const base = `http://127.0.0.1:5101/${demoProject}/asia-northeast3/api`;
type Actor = { uid: string; token: string; handle: string };
let a: Actor, b: Actor, c: Actor;

// Exercise real Firestore Rules through the official REST protocol, using the
// Auth emulator's actual ID tokens. No simulated authorization implementation.
async function firestore(method: string, path: string, current?: Actor, body?: unknown, commit = false) {
  const response = await fetch(`http://127.0.0.1:8280/v1/projects/${demoProject}/databases/(default)/documents${commit ? ':commit' : `/${path}`}`, {
    method, headers: { 'Content-Type': 'application/json', ...(current ? { Authorization: `Bearer ${current.token}` } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return response.status;
}
async function loadRules(file: string) {
  const response = await fetch(`http://127.0.0.1:8280/emulator/v1/projects/${demoProject}:securityRules`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ rules: { files: [{ content: await readFile(file, 'utf8') }] } }),
  });
  assert.equal(response.status, 200, 'local security rules compilation');
}

async function call(path: string, actor?: Actor, method = 'GET', body?: unknown,
    headerOverrides: Record<string, string> = {}) {
  const response = await fetch(base + path, { method,
    headers: { 'Content-Type': 'application/json', ...(actor ? {
      Authorization: `Bearer ${actor.token}`, 'X-Airzero-Session': actor.handle } : {}), ...headerOverrides },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  return { status: response.status, body: await response.json() as Record<string, any> };
}
async function actor(uid: string, verified = true): Promise<Actor> {
  const email = `${uid}@example.test`, password = 'Synthetic-local-only-2026!';
  await auth.createUser({ uid, email, password, emailVerified: verified });
  const result = await fetch('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  assert.equal(result.status, 200, 'synthetic local sign-in');
  const value = await result.json() as { idToken: string };
  const current = { uid, token: value.idToken, handle: '' };
  if (verified) {
    const start = await call('/v1/session/start', current, 'POST', {});
    assert.equal(start.status, 200, 'server session start');
    current.handle = start.body.sessionHandle as string;
  }
  return current;
}
function changedToken(current: Actor, changes: Record<string, unknown>): Actor {
  const parts = current.token.split('.');
  const payload = JSON.parse(Buffer.from(parts[1]!, 'base64url').toString());
  parts[1] = Buffer.from(JSON.stringify({ ...payload, ...changes })).toString('base64url');
  return { ...current, token: parts.join('.') };
}

before(async () => {
  await loadRules('firestore.rules');
  await db.doc(`${scope}/public/catalog`).set({ schema: 1, published: true,
    stages: Array.from({ length: 15 }, (_, i) => i + 1), freeContent: ['aurora', 'pilot', 'standard', 'barrier'] });
  a = await actor('fictional_a'); b = await actor('fictional_b'); c = await actor('fictional_c');
}, { timeout: 60000 });
after(async () => { await deleteApp(app); });

test('public data is minimal while every direct private read/write/list/delete is denied', async () => {
  assert.equal((await call('/v1/public/catalog')).status, 200);
  assert.equal(await firestore('GET', `${scope}/public/catalog`), 200);
  for (const client of [undefined, a, b]) {
    for (const uid of [a.uid, b.uid]) {
      const path = `${scope}/accounts/${uid}/private/progress`;
      assert.equal(await firestore('GET', path, client), 403);
      assert.equal(await firestore('PATCH', path, client, { fields: { premium: { booleanValue: true } } }), 403);
      assert.equal(await firestore('DELETE', path, client), 403);
      assert.equal(await firestore('GET', `${scope}/accounts/${uid}/private`, client), 403);
    }
    assert.equal(await firestore('PATCH', `${scope}/public/catalog`, client, { fields: { published: { booleanValue: true } } }), 403);
    assert.equal(await firestore('GET', `${scope}/public`, client), 403);
    assert.equal(await firestore('GET', 'apps/other-app/environments/dev/public/catalog', client), 403);
    assert.equal(await firestore('GET', 'apps/airzero-strike/environments/prod/public/catalog', client), 403);
  }
  assert.equal(await firestore('POST', '', a, { writes: [a.uid, b.uid].map((uid) => ({ update: {
    name: `projects/${demoProject}/databases/(default)/documents/${scope}/accounts/${uid}/private/preferences`,
    fields: { sensitivity: { doubleValue: 1 } },
  } })) }, true), 403);
});

test('verified A/B see only their own record and foreign session handles cannot access it', async () => {
  assert.equal((await call('/v1/me/progress', a)).body.unlocked, 1);
  assert.equal((await call('/v1/me/progress', b)).body.imported, false);
  assert.equal((await call('/v1/me/progress', { ...b, handle: a.handle })).status, 401);
  assert.equal((await call(`/v1/users/${a.uid}/progress`, b)).status, 404);
  assert.equal((await call('/v1/me/progress')).status, 401);
  assert.equal((await call('/v1/me/progress?uid=fictional_b', a)).status, 400);
});

const guest = { schema: 1, records: [{ stage: 1, cleared: true, best: 900, attempts: 2 }] };
test('guest import needs confirmation and CAS; duplicate calls are idempotent, existing progress is preserved', async () => {
  const preview = await call('/v1/me/import-preview', a, 'POST', {});
  assert.equal(preview.body.decision, 'empty_requires_confirmation');
  const payload = { guest, confirmed: true, operationId: 'import_fixture_a_0001', expectedRevision: 0, generation: 0 };
  assert.equal((await call('/v1/me/import-guest', a, 'POST', { ...payload, confirmed: false })).status, 409);
  assert.equal((await call('/v1/me/import-guest', a, 'POST', { ...payload, uid: b.uid })).status, 400);
  assert.equal((await call('/v1/me/import-guest', a, 'POST', { ...payload, premium: true })).status, 400);
  const first = await call('/v1/me/import-guest', a, 'POST', payload);
  assert.equal(first.status, 200); assert.equal(first.body.unlocked, 2);
  assert.equal((await call('/v1/me/import-guest', a, 'POST', payload)).body.revision, 1);
  assert.equal((await call('/v1/me/import-guest', a, 'POST', { ...payload,
    guest: { ...guest, records: [{ ...guest.records[0], best: 901 }] } })).status, 409);
  assert.equal((await call('/v1/me/import-guest', a, 'POST', { ...payload, operationId: 'import_fixture_a_0002', expectedRevision: 1 })).status, 409);
  assert.equal((await call('/v1/me/import-preview', a, 'POST', {})).body.decision, 'conflict_keep_both');
  assert.equal((await call('/v1/me/progress', a)).body.records[0].best, 900);
  assert.equal((await call('/v1/me/progress', b)).body.imported, false);
});

test('two devices with one UID cannot overwrite the same revision concurrently', async () => {
  const started = await call('/v1/session/start', b, 'POST', {});
  const second = { ...b, handle: started.body.sessionHandle as string };
  const payload = { guest, confirmed: true, expectedRevision: 0, generation: 0 };
  const values = await Promise.all([
    call('/v1/me/import-guest', b, 'POST', { ...payload, operationId: 'import_fixture_b_first' }),
    call('/v1/me/import-guest', second, 'POST', { ...payload, operationId: 'import_fixture_b_second' }),
  ]);
  assert.deepEqual(values.map((r) => r.status).sort(), [200, 409]);
  assert.equal((await call('/v1/me/progress', b)).body.revision, 1);
});

test('pre-existing non-imported records and stale data generations are never overwritten', async () => {
  const current = await actor('fictional_existing');
  const path = `${scope}/accounts/${current.uid}/private/progress`;
  await db.doc(path).set({ schema: 1, revision: 4, generation: 0, imported: false,
    records: guest.records, unlocked: 2 });
  assert.equal((await call('/v1/me/import-preview', current, 'POST', {})).body.decision, 'conflict_keep_both');
  const payload = { guest, confirmed: true, operationId: 'existing_import_001', expectedRevision: 4, generation: 0 };
  assert.equal((await call('/v1/me/import-guest', current, 'POST', payload)).status, 409);
  assert.equal((await db.doc(path).get()).data()!.revision, 4);
  await db.doc(path).update({ generation: 1 });
  assert.equal((await call('/v1/me/import-guest', current, 'POST', payload)).status, 409);
});

test('personal settings updates/reset require ownership and revision; guest game data survives', async () => {
  const payload = { operationId: 'preferences_fixture_001', expectedRevision: 0, generation: 0,
    settings: { ...defaultPreferences, sensitivity: 1.25 } };
  assert.equal((await call('/v1/me/preferences', a, 'PUT', payload)).status, 200);
  assert.equal((await call('/v1/me/preferences', { ...b, handle: a.handle }, 'PUT', payload)).status, 401);
  assert.equal((await call('/v1/me/preferences', b, 'PUT', { ...payload, uid: a.uid })).status, 400);
  assert.equal((await call('/v1/me/preferences', a, 'PUT', { ...payload, operationId: 'preferences_stale_001' })).status, 409);
  assert.equal((await call('/v1/me/preferences', a, 'DELETE', {
    operationId: 'preferences_reset_001', expectedRevision: 1, generation: 0 })).status, 200);
  assert.equal((await call('/v1/me/preferences', a)).body.settings.sensitivity, 1);
  assert.equal((await call('/v1/me/progress', a)).body.records[0].best, 900);
  assert.equal((await call(`/v1/users/${a.uid}/preferences`, b, 'DELETE', {})).status, 404);
});

test('entitlements cannot be changed by client fields/rules or legacy local completion flags', async () => {
  assert.equal((await call('/v1/me/entitlement', a)).body.status, 'unverified');
  const path = `${scope}/accounts/${a.uid}/private/entitlement_play`;
  assert.equal(await firestore('PATCH', path, a, { fields: { verified: { booleanValue: true } } }), 403);
  assert.equal((await call('/v1/me/entitlement', a, 'PUT', { verified: true })).status, 404);
  const r = { app: 'airzero-strike', environment: 'dev', owner: a.uid, store: 'play',
    source: 'google-server', verified: true, status: 'canceled', validUntilMs: Date.now() + 60000 };
  for (const change of [{ owner: b.uid }, { app: 'other-app' }, { environment: 'prod' },
    { store: 'app-store' }, { verified: false }, { status: 'pending' }, { status: 'failed' },
    { status: 'revoked' }, { validUntilMs: Date.now() - 1 }]) {
    await db.doc(path).set({ ...r, ...change });
    assert.equal((await call('/v1/me/entitlement', a)).body.status, 'unverified');
  }
  await db.doc(path).set(r); // Legacy fixture is not an official store verification.
  const accepted = await call('/v1/me/entitlement', a);
  assert.equal(accepted.body.status, 'unverified'); assert.equal(accepted.body.owned.includes('vector'), false);
  assert.equal((await call('/v1/me/entitlement', b)).body.status, 'unverified');
});

test('expired, malformed, wrong-project and raw custom tokens are refused without leaking input', async () => {
  for (const bad of [{ ...a, token: 'not-a-token' }, changedToken(a, { exp: 1 }),
    changedToken(a, { aud: 'demo-other-app', iss: 'https://securetoken.google.com/demo-other-app' }),
    changedToken(a, { aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit' })]) {
    const reply = await call('/v1/me/progress', bad);
    assert.equal(reply.status, 401);
    assert.deepEqual(Object.keys(reply.body).sort(), ['error', 'requestId']);
    assert.equal(JSON.stringify(reply.body).includes(bad.token), false);
    for (const method of ['PUT', 'DELETE']) {
      assert.equal((await call('/v1/me/preferences', bad, method, {
        operationId: 'expired_change_001', expectedRevision: 0, generation: 0,
        ...(method === 'PUT' ? { settings: defaultPreferences } : {}),
      })).status, 401);
    }
  }
  const unverified = await actor('fictional_unverified', false);
  assert.equal((await call('/v1/session/start', unverified, 'POST', {})).status, 403);
});

test('disabled, deleted, generation-changed and expired sessions lose access', async () => {
  const revoked = await actor('fictional_revoked');
  await auth.revokeRefreshTokens(revoked.uid);
  assert.equal((await call('/v1/me/progress', changedToken(revoked, { auth_time: 1 }))).status, 401);
  const disabled = await actor('fictional_disabled');
  await auth.updateUser(disabled.uid, { disabled: true });
  assert.equal((await call('/v1/me/progress', disabled)).status, 401);
  await db.doc(`${scope}/accounts/${c.uid}`).update({ status: 'deleted' });
  assert.equal((await call('/v1/me/progress', c)).status, 401);
  assert.equal((await call('/v1/session/start', c, 'POST', {})).status, 403);
  const stale = await actor('fictional_stale');
  await db.doc(`${scope}/accounts/${stale.uid}`).update({ generation: 1 });
  assert.equal((await call('/v1/me/progress', stale)).status, 401);
  const expired = await actor('fictional_expired');
  const hash = createHash('sha256').update(expired.handle).digest('hex');
  await db.doc(`${scope}/sessions/${hash}`).update({ expiresAtMs: 1 });
  assert.equal((await call('/v1/me/progress', expired)).status, 401);
});

test('provider subject mappings are server-only and never reassigned over another UID', async () => {
  const { providerKey } = await import('../src/repository.js');
  const reference = db.doc(`${scope}/providers/${providerKey('password', b.uid)}`);
  const old = (await reference.get()).data()!;
  assert.equal(old.subject, b.uid);
  await reference.update({ uid: a.uid });
  assert.equal((await call('/v1/session/start', b, 'POST', {})).status, 409);
  assert.equal((await reference.get()).data()!.uid, a.uid);
  await reference.set(old);
});

test('logout closes its session, blocks token replay at start and preserves records', async () => {
  assert.equal((await call('/v1/session/end', a, 'POST', {})).status, 200);
  assert.equal((await call('/v1/me/progress', a)).status, 401);
  assert.equal((await call('/v1/me/preferences', a, 'DELETE', {
    operationId: 'logout_reset_0001', expectedRevision: 2, generation: 0 })).status, 401);
  assert.equal((await call('/v1/me/preferences', undefined, 'PUT', {
    operationId: 'anonymous_put_001', expectedRevision: 0, generation: 0, settings: defaultPreferences })).status, 401);
  assert.equal((await call('/v1/me/preferences', undefined, 'DELETE', {
    operationId: 'anonymous_reset_001', expectedRevision: 0, generation: 0 })).status, 401);
  assert.equal((await call('/v1/session/start', a, 'POST', {})).status, 401);
  assert.equal((await db.doc(`${scope}/accounts/${a.uid}/private/progress`).get()).data()!.records[0].best, 900);
  assert.equal((await call('/v1/me/progress', b)).status, 200);
});

test('production rules permit only the production public catalog and deny all private clients', async () => {
  await loadRules('firestore.prod.rules');
    const path = 'apps/airzero-strike/environments/prod/public/catalog';
    await db.doc(path).set({ schema: 1, published: true, stages: [1], freeContent: ['aurora'] });
    assert.equal(await firestore('GET', path), 200);
    assert.equal(await firestore('GET', `${scope}/public/catalog`), 403);
    assert.equal(await firestore('GET', `apps/airzero-strike/environments/prod/accounts/${b.uid}/private/progress`, b), 403);
    await db.doc(path).set({ schema: 1, published: true, stages: [1], freeContent: ['aurora'], privateData: 'synthetic' });
    assert.equal(await firestore('GET', path), 403);
});
