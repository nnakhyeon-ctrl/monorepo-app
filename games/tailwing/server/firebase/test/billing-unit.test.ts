import test from 'node:test';
import assert from 'node:assert/strict';
import { loadBillingConfig, parsePlay, permits, OfficialStoreVerifier, type BillingConfig } from '../src/billing-store.js';
import { loadConfig } from '../src/security.js';
import { sealReference, openReference } from '../src/billing.js';
const config: BillingConfig = { ready: true, play: { product: 'fixture_premium', monthly: 'fixture-month', annual: 'fixture-year', pushEmail: '', pushAudience: '' } };
function play(state = 'SUBSCRIPTION_STATE_ACTIVE') {
  return { subscriptionState: state, testPurchase: {}, externalAccountIdentifiers: { obfuscatedExternalAccountId: '11111111-1111-4111-a111-111111111111' },
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING', lineItems: [{ productId: 'fixture_premium',
      offerDetails: { basePlanId: 'fixture-month' }, expiryTime: '2030-01-01T00:00:00Z', autoRenewingPlan: { autoRenewEnabled: true } }] };
}
test('billing is closed without explicit settings; READY alone cannot configure products/secrets', () => {
  assert.deepEqual(loadBillingConfig({}), { ready: false });
  assert.throws(() => loadBillingConfig({ AIRZERO_BILLING_READY: 'true' }));
});
test('enabled configuration requires dedicated worker/push identities, exact audience and policy/retention readiness', () => {
  const env = { AIRZERO_BILLING_READY: 'true', AIRZERO_BILLING_SEAL_KEY: Buffer.alloc(32, 7).toString('base64'),
    AIRZERO_BILLING_NOTIFICATIONS_READY: 'true', AIRZERO_BILLING_POLICY_READY: 'true', AIRZERO_BILLING_RETENTION_READY: 'true',
    AIRZERO_PROJECT_ID: 'airzero-strike-fixture', AIRZERO_REGION: 'asia-northeast3',
    AIRZERO_BILLING_WORKER_EMAIL: 'airzero-billing-worker-dev@airzero-strike-fixture.iam.gserviceaccount.com',
    AIRZERO_BILLING_WORKER_AUDIENCE: 'https://asia-northeast3-airzero-strike-fixture.cloudfunctions.net/api/v1/billing/maintenance',
    AIRZERO_PLAY_SUBSCRIPTION_ID: 'fixture_premium', AIRZERO_PLAY_MONTHLY_PLAN: 'fixture-month', AIRZERO_PLAY_ANNUAL_PLAN: 'fixture-year',
    AIRZERO_PLAY_PUSH_EMAIL: 'airzero-billing-push-dev@airzero-strike-fixture.iam.gserviceaccount.com',
    AIRZERO_PLAY_PUSH_AUDIENCE: 'https://asia-northeast3-airzero-strike-fixture.cloudfunctions.net/api/v1/billing/notifications/play' };
  assert.equal(loadBillingConfig(env).ready, true);
  for (const change of [{ AIRZERO_BILLING_POLICY_READY: 'false' }, { AIRZERO_BILLING_RETENTION_READY: 'false' },
    { AIRZERO_BILLING_WORKER_AUDIENCE: env.AIRZERO_PLAY_PUSH_AUDIENCE }, { AIRZERO_PLAY_PUSH_EMAIL: 'other-app@example.test' }]) {
    assert.throws(() => loadBillingConfig({ ...env, ...change }));
  }
});
test('Play pending, hold, pause and expiry never grant; canceled/grace use official remaining expiry', () => {
  for (const state of ['SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_PAUSED', 'SUBSCRIPTION_STATE_EXPIRED']) {
    assert.equal(permits(parsePlay(play(state), config, 'dev'), Date.now()), false);
  }
  for (const state of ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_CANCELED', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD']) {
    const value = parsePlay(play(state), config, 'dev'); assert.equal(permits(value, Date.now()), true);
    assert.equal(permits(value, value.validUntilMs), false);
  }
});
test('official response must match environment/product/base plan/account binding and auto-renewable type', () => {
  assert.throws(() => parsePlay(play(), config, 'prod'));
  const p = play(); delete (p as { testPurchase?: unknown }).testPurchase;
  assert.throws(() => parsePlay(p, config, 'dev'));
  for (const mutate of [(p: any) => p.lineItems[0].productId = 'other_app',
    (p: any) => p.lineItems[0].offerDetails.basePlanId = 'unknown',
    (p: any) => p.lineItems[0].offerDetails.offerId = 'unapproved_trial',
    (p: any) => p.lineItems[0].autoRenewingPlan = undefined,
    (p: any) => p.lineItems[0].autoRenewingPlan.installmentDetails = { remainingCommittedPaymentsCount: 12 },
    (p: any) => p.lineItems[0].prepaidPlan = {},
    (p: any) => p.externalAccountIdentifiers = {}]) {
    const p = play(); mutate(p); assert.throws(() => parsePlay(p, config, 'dev'));
  }
});
test('purchase references use randomized authenticated encryption scoped to app/environment/ledger', () => {
  const key = Buffer.alloc(32, 7), value = 'fictional_purchase_reference';
  const a = sealReference(value, key, 'fixture/dev/a'), b = sealReference(value, key, 'fixture/dev/a');
  assert.notEqual(a, b); assert.equal(a.includes(value), false);
  assert.equal(openReference(a, key, 'fixture/dev/a'), value);
  assert.throws(() => openReference(a, key, 'other-app/dev/a'));
  assert.throws(() => openReference(a, Buffer.alloc(32, 8), 'fixture/dev/a'));
});
test('official adapters reject unsigned push credentials and arbitrary transaction references before delivery', async () => {
  const runtime = loadConfig({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-airzero-strike',
    FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9299', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8280' });
  const v = new OfficialStoreVerifier(runtime, config);
  await assert.rejects(v.worker());
  await assert.rejects(v.notification('play', { message: { data: 'e30=' } }, 'Bearer unsigned'));
  await assert.rejects(v.resolve('play', '\nnot a purchase'));
  await assert.rejects(v.resolve('app-store', 'untrusted-client-jwt'));
});
