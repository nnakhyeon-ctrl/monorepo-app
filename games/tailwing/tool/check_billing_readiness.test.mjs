import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { evaluateBillingSetup } from './check_billing_readiness.mjs';
const blank = () => JSON.parse(readFileSync(new URL('../config/billing.public.example.json', import.meta.url), 'utf8'));
function configured() {
  const f = blank();
  for (const k of ['AIRZERO_PLAY_SUBSCRIPTION_ID', 'AIRZERO_APPLE_MONTHLY_PRODUCT', 'AIRZERO_APPLE_ANNUAL_PRODUCT']) f[k] = `fixture.${k.toLowerCase()}`;
  f.AIRZERO_PLAY_MONTHLY_PLAN = 'fixture-month'; f.AIRZERO_PLAY_ANNUAL_PLAN = 'fixture-year';
  f.AIRZERO_APPLE_SUBSCRIPTION_GROUP = '111'; f.AIRZERO_APPLE_STORE_APP_ID = '222';
  for (const k of Object.keys(f).filter(k => k.endsWith('_URL'))) f[k] = 'https://example.com/policy';
  return f;
}
test('undecided product IDs stay pending and purchase disabled; values are never echoed', () => {
  const r = evaluateBillingSetup(blank());
  assert.equal(r.localStatus, 'PENDING'); assert.equal(r.liveVerification, 'NOT_RUN');
  assert.equal(r.checks.filter(c => c.code === 'not_configured').length, 11);
});
test('complete public formats and READY flag never claim an actual connection', () => {
  const f = configured(); f.AIRZERO_BILLING_READY = true;
  const r = evaluateBillingSetup(f); assert.equal(r.localStatus, 'PENDING');
  assert.equal(r.liveVerification, 'NOT_RUN'); assert.equal(JSON.stringify(r).includes(f.AIRZERO_PLAY_SUBSCRIPTION_ID), false);
});
test('unexpected secret fields and malformed schemas fail without echoing values or fields', () => {
  const f = configured(); f.DO_NOT_ECHO_FIELD = 'DO_NOT_ECHO_VALUE';
  const output = JSON.stringify(evaluateBillingSetup(f));
  assert.equal(output.includes('DO_NOT_ECHO'), false); assert.equal(evaluateBillingSetup(f).localStatus, 'BLOCKED');
  assert.equal(evaluateBillingSetup([]).localStatus, 'BLOCKED');
});
test('foreign identifiers and duplicate products/plans are rejected', () => {
  for (const mutate of [f => f.AIRZERO_ENVIRONMENT = 'prod', f => f.AIRZERO_ANDROID_PACKAGE += '.integration',
    f => f.AIRZERO_PLAY_ANNUAL_PLAN = f.AIRZERO_PLAY_MONTHLY_PLAN,
    f => f.AIRZERO_APPLE_ANNUAL_PRODUCT = f.AIRZERO_APPLE_MONTHLY_PRODUCT]) {
    const f = configured(); mutate(f); assert.equal(evaluateBillingSetup(f).localStatus, 'BLOCKED');
  }
});
test('local, non-HTTPS and credential/query-bearing policy addresses are rejected', () => {
  for (const value of ['http://example.com', 'https://localhost/policy', 'https://a:b@example.com', 'https://example.com/?token=hidden']) {
    const f = configured(); f.AIRZERO_TERMS_URL = value; assert.equal(evaluateBillingSetup(f).localStatus, 'BLOCKED');
  }
});
