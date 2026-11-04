import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { Auth, DecodedIdToken } from 'firebase-admin/auth';
import type { AppCheck } from 'firebase-admin/app-check';
import { ApiError, bearer, demoProject, FirebaseSessionVerifier, loadConfig, recent,
  type RuntimeConfig } from '../src/security.js';
import { defaultPreferences, guestProgress, integer, object, operation, preferences } from '../src/validation.js';

const emulator = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: demoProject,
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9299', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8280' };
const cloud = { GCLOUD_PROJECT: 'airzero-strike-prod-fixture', AIRZERO_PROJECT_ID: 'airzero-strike-prod-fixture',
  AIRZERO_SERVICE_ACCOUNT: 'airzero-auth-api@airzero-strike-prod-fixture.iam.gserviceaccount.com',
  AIRZERO_ENVIRONMENT: 'prod', AIRZERO_REGION: 'asia-northeast3', AIRZERO_FIREBASE_APP_IDS: '1:123:android:abcdef' };
const now = 1800000000000;
function token(overrides: Record<string, unknown> = {}): DecodedIdToken {
  return { aud: demoProject, iss: `https://securetoken.google.com/${demoProject}`, uid: 'fictional_a',
    sub: 'fictional_a', exp: now / 1000 + 60, iat: now / 1000 - 10, auth_time: now / 1000 - 20,
    firebase: { sign_in_provider: 'password', identities: {} }, email_verified: true, ...overrides } as DecodedIdToken;
}
function fixture(value = token(), config = loadConfig(emulator), verified = true) {
  const calls: boolean[] = [];
  const auth = { verifyIdToken: async (_token: string, revoked: boolean) => { calls.push(revoked); return value; },
    getUser: async () => ({ uid: 'fictional_a', disabled: false, emailVerified: verified,
      providerData: [{ providerId: 'password', uid: 'not-used@example.test' }] }) } as unknown as Auth;
  const appCheck = { verifyToken: async () => ({ appId: '1:123:android:abcdef' }) } as unknown as AppCheck;
  return { verifier: new FirebaseSessionVerifier(auth, appCheck, config, () => now), calls };
}

test('environment defaults closed and emulator is confined to one loopback demo project', () => {
  assert.throws(() => loadConfig({}));
  assert.equal(loadConfig(emulator).mode, 'emulator');
  for (const change of [{ GCLOUD_PROJECT: 'other-app' }, { FIRESTORE_EMULATOR_HOST: '0.0.0.0:8280' },
    { FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099' }]) assert.throws(() => loadConfig({ ...emulator, ...change }));
  assert.equal(loadConfig(cloud).mode, 'cloud');
  assert.throws(() => loadConfig({ ...cloud, FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9299' }));
  assert.throws(() => loadConfig({ ...cloud, AIRZERO_FIREBASE_APP_IDS: '' }));
  assert.throws(() => loadConfig({ ...cloud, AIRZERO_PROJECT_ID: 'other-app' }));
  assert.throws(() => loadConfig({ ...cloud, AIRZERO_SERVICE_ACCOUNT: '' }));
  assert.throws(() => loadConfig({ ...cloud, AIRZERO_SERVICE_ACCOUNT: 'airzero-auth-api@other-app.iam.gserviceaccount.com' }));
});
test('Firebase verifier requests revocation checks and uses provider subject instead of email', async () => {
  const f = fixture();
  const identity = await f.verifier.verify('synthetic-fixture');
  assert.deepEqual(f.calls, [true]);
  assert.equal(identity.uid, 'fictional_a');
  assert.equal(identity.providers[0]!.subject, 'fictional_a');
  assert.equal(identity.store, 'play');
});
test('expired, wrong issuer/audience, future, anonymous, unsupported and unverified sessions fail', async () => {
  for (const bad of [{ exp: now / 1000 }, { aud: 'other-app' }, { iss: 'fake-issuer' }, { sub: 'fictional_b' },
    { iat: now / 1000 + 100 }, { auth_time: now / 1000 + 100 },
    { firebase: { sign_in_provider: 'anonymous', identities: {} } },
    { firebase: { sign_in_provider: 'custom', identities: {} } }]) {
    await assert.rejects(fixture(token(bad)).verifier.verify('synthetic-fixture'), ApiError);
  }
  await assert.rejects(fixture(token(), undefined, false).verifier.verify('synthetic-fixture'), ApiError);
});
test('real environments require an allowed verified App Check app and matching project identity', async () => {
  const config = loadConfig(cloud);
  const valid = token({ aud: config.projectId, iss: `https://securetoken.google.com/${config.projectId}` });
  const f = fixture(valid, config);
  await assert.rejects(f.verifier.verify('synthetic-fixture'), ApiError);
  assert.equal((await f.verifier.verify('synthetic-fixture', 'synthetic-app-proof')).store, 'play');
  const other: RuntimeConfig = { ...config, appIds: new Set(['1:123:ios:abcdef']) };
  await assert.rejects(fixture(valid, other).verifier.verify('synthetic-fixture', 'synthetic-app-proof'), ApiError);
});
test('authorization and recent-auth checks reject unsafe input', () => {
  for (const bad of [undefined, '', 'bearer abc', 'Bearer a b', 'Bearer abc\nextra']) assert.throws(() => bearer(bad), ApiError);
  assert.equal(bearer('Bearer a.b.c'), 'a.b.c');
  assert.throws(() => recent({ ...token(), uid: 'fictional_a', issuedAt: 0, authTime: now / 1000 - 301,
    expiresAt: now + 1000, providers: [], store: 'play' }, now), ApiError);
});

test('direct Firebase provider linking cannot implicitly create an app social binding', async () => {
  const auth = { verifyIdToken: async () => token(), getUser: async () => ({ uid: 'fictional_a', disabled: false,
    emailVerified: true, providerData: [{ providerId: 'password', uid: 'fictional_a' },
      { providerId: 'google.com', uid: 'direct_client_link_subject' }] }) } as unknown as Auth;
  const identity = await new FirebaseSessionVerifier(auth, {} as AppCheck, loadConfig(emulator), () => now).verify('synthetic-fixture');
  assert.deepEqual(identity.providers, [{ provider: 'password', subject: 'fictional_a' }]);
  assert.equal(identity.passwordRequiresApproval, true);
});
test('only known bounded record fields are accepted; stage progression is contiguous', () => {
  const progress = { schema: 1, records: [{ stage: 1, cleared: true, best: 900, attempts: 2 }] };
  assert.equal(guestProgress(progress).records[0]!.best, 900);
  for (const bad of [{ ...progress, uid: 'fictional_b' }, { ...progress, premium: true },
    { ...progress, records: [{ stage: 15, cleared: true, best: 1, attempts: 1 }] },
    { ...progress, records: [{ stage: 1, cleared: true, best: Number.MAX_SAFE_INTEGER, attempts: 2 }] }]) {
    assert.throws(() => guestProgress(bad), ApiError);
  }
  assert.throws(() => object({ price: 1 }, []), ApiError);
  assert.throws(() => integer(NaN), ApiError);
  assert.throws(() => operation('../fictional_b'), ApiError);
});
test('personal settings use existing bounded fields and cannot carry permissions', () => {
  assert.deepEqual(preferences(defaultPreferences), defaultPreferences);
  assert.throws(() => preferences({ ...defaultPreferences, owned: ['vector'] }), ApiError);
  assert.throws(() => preferences({ ...defaultPreferences, sensitivity: 900 }), ApiError);
  assert.throws(() => preferences({ ...defaultPreferences, sensitivity: 1.1 }), ApiError);
  assert.throws(() => preferences({ ...defaultPreferences, effectsVolume: -1 }), ApiError);
});
