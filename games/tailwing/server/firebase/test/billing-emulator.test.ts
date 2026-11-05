import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { Buffer } from 'node:buffer';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import type { AppCheck } from 'firebase-admin/app-check';
import { AccountRepository } from '../src/repository.js';
import { BillingService, detachBillingData } from '../src/billing.js';
import { permits, type BillingConfig, type Store, type StoreVerifier, type VerifiedSubscription } from '../src/billing-store.js';
import { ApiError, demoProject, FirebaseSessionVerifier, loadConfig } from '../src/security.js';
import { sha256 } from '../src/social-proof.js';
if (process.env.GCLOUD_PROJECT !== demoProject || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9299' ||
    process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8280') throw new Error('local_demo_only');
const app = initializeApp({ projectId: demoProject }, 'billing-fixtures'), auth = getAuth(app), db = getFirestore(app);
const config = loadConfig({ ...process.env, FUNCTIONS_EMULATOR: 'true' });
let time = Date.now(), sequence = 0;
const now = () => time, accounts = new AccountRepository(db, config, now);
const sessions = new FirebaseSessionVerifier(auth, {} as AppCheck, config, now);
const settings: BillingConfig = { ready: true, sealKey: Buffer.alloc(32, 7),
  play: { product: 'fixture_premium', monthly: 'fixture-month', annual: 'fixture-year', pushEmail: '', pushAudience: '' },
  apple: { monthly: 'fixture_ios_month', annual: 'fixture_ios_year', group: '1', appId: 1, key: '', keyId: '', issuer: '' } };
class FixtureVerifier implements StoreVerifier {
  values = new Map<string, VerifiedSubscription>();
  acks = 0; failAck = false; authorizedPush = true; gate?: Promise<void>; entered?: () => void;
  async resolve(_store: Store, ref: string) { return ref; }
  async verify(_store: Store, ref: string) {
    this.entered?.();
    if (this.gate) await this.gate;
    const v = this.values.get(ref); if (!v) throw new ApiError(403, 'purchase_scope_denied');
    return { ...v };
  }
  async acknowledge(v: VerifiedSubscription) {
    this.acks++; if (this.failAck) throw new Error('fictional_ack_failed');
    this.values.get(v.reference)!.acknowledged = true;
  }
  async notification(_store: Store, body: unknown) {
    if (!this.authorizedPush) throw new ApiError(401, 'invalid_notification');
    return (body as { reference: string }).reference;
  }
  async worker() { if (!this.authorizedPush) throw new ApiError(401, 'invalid_notification'); }
}
type Actor = { uid: string; token: string; handle: string; binding: string };
async function fixture() {
  time = Date.now();
  const verifier = new FixtureVerifier(), service = new BillingService(config, settings, db, accounts, sessions, verifier, now);
  async function actor(): Promise<Actor> {
    const uid = `billing_fixture_${++sequence}`, password = 'Synthetic subscription test passphrase';
    const email = `${uid}@example.test`;
    await auth.createUser({ uid, email, password, emailVerified: true });
    const r = await fetch('http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, returnSecureToken: true }) });
    assert.equal(r.status, 200);
    const data = await r.json() as { idToken: string }, identity = await sessions.verify(data.idToken);
    const s = await accounts.start(identity);
    const a = { uid, token: data.idToken, handle: s.sessionHandle as string, binding: '' };
    a.binding = (await call(a, 'intent', { period: 'monthly' })).binding as string;
    return a;
  }
  const call = (a: Actor, action: string, body: unknown = {}) => service.handle(action, body, `Bearer ${a.token}`, undefined, a.handle);
  function purchase(a: Actor, suffix = 'a', state: VerifiedSubscription['state'] = 'active') {
    const reference = `fictional_reference_${a.uid}_${suffix}`;
    verifier.values.set(reference, { store: 'play', reference, product: 'fixture_premium', period: 'monthly', binding: a.binding,
      state, validUntilMs: time + 86400000, autoRenew: true, acknowledged: false });
    return reference;
  }
  return { service, verifier, actor, call, purchase };
}
after(async () => { await deleteApp(app); });
test('server maps verified UID binding; A proof cannot grant B, foreign app product, store or owner', async () => {
  const f = await fixture(), a = await f.actor(), b = await f.actor(), ref = f.purchase(a);
  await assert.rejects(f.call(b, 'verify', { productId: 'fixture_premium', reference: ref }), ApiError);
  await assert.rejects(f.call(a, 'verify', { productId: 'other_app', reference: ref }), ApiError);
  f.verifier.values.get(ref)!.store = 'app-store';
  await assert.rejects(f.call(a, 'verify', { productId: 'fixture_premium', reference: ref }), ApiError);
  assert.equal((await f.call(b, 'status')).status, 'unverified');
});
test('pending grants nothing; verified delivery is persisted, acknowledged once and duplicate callbacks are idempotent', async () => {
  const f = await fixture(), a = await f.actor(), ref = f.purchase(a, 'pending', 'pending');
  let r = await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  assert.equal(r.finish, false); assert.equal((r.entitlement as any).status, 'pending'); assert.equal(f.verifier.acks, 0);
  f.verifier.values.get(ref)!.state = 'active';
  r = await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  assert.equal(r.finish, true); assert.equal((r.entitlement as any).status, 'active');
  await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  assert.equal(f.verifier.acks, 1);
  await assert.rejects(f.call(a, 'intent', { period: 'annual' }), ApiError);
  const record = (await db.doc(`${accounts.scope}/billingLedger/${sha256(`play\0${ref}`)}`).get()).data()!;
  assert.equal(JSON.stringify(record).includes(ref), false);
});
test('failed acknowledgement stays unverified and retry recovers without consuming or repurchasing', async () => {
  const f = await fixture(), a = await f.actor(), ref = f.purchase(a);
  f.verifier.failAck = true;
  await assert.rejects(f.call(a, 'verify', { productId: 'fixture_premium', reference: ref }));
  assert.equal((await f.call(a, 'status')).status, 'unverified');
  f.verifier.failAck = false;
  const r = await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  assert.equal((r.entitlement as any).status, 'active');
});
test('monthly and annual verified subscriptions include every advanced skill; pending and revoked replies keep them locked', async () => {
  const advanced = ['missile_storm', 'beam', 'absorb', 'blackhole', 'emp', 'chain',
    'petal_orbit', 'aurora_sweep', 'landing_beacon', 'gyro', 'capacitor', 'safety_cell'];
  for (const period of ['monthly', 'annual'] as const) {
    const f = await fixture(), a = await f.actor(), ref = f.purchase(a, period, 'pending');
    const value = f.verifier.values.get(ref)!; value.period = period;
    let response = await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
    assert.deepEqual((response.entitlement as any).owned, []);
    value.state = 'active';
    response = await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
    const entitlement = response.entitlement as { period: string; owned: string[] };
    assert.equal(entitlement.period, period);
    for (const id of advanced) assert.ok(entitlement.owned.includes(id));
    value.state = 'revoked';
    await f.service.background('play', { reference: ref });
    assert.deepEqual((await f.call(a, 'status')).owned, []);
  }
});
test('authentic duplicate/reversed notifications requery canonical state; cancellation, grace, hold, expiry/refund preserve game data', async () => {
  const f = await fixture(), a = await f.actor(), ref = f.purchase(a);
  await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  const progress = db.doc(`${accounts.scope}/accounts/${a.uid}/private/progress`); await progress.set({ fictionalBest: 777 });
  for (const state of ['canceled', 'grace', 'hold', 'expired', 'revoked'] as const) {
    f.verifier.values.get(ref)!.state = state;
    await f.service.background('play', { reference: ref, staleEvent: 'active' });
    await f.service.background('play', { reference: ref, duplicate: true });
    const r = await f.call(a, 'status'); assert.equal(r.status, state);
    assert.equal(r.leaseUntilMs !== null, permits(f.verifier.values.get(ref)!, time));
  }
  assert.equal((await progress.get()).data()!.fictionalBest, 777);
  f.verifier.authorizedPush = false;
  await assert.rejects(f.service.background('play', { reference: ref }), ApiError);
  await assert.rejects(f.service.background('maintenance', {}), ApiError);
});
test('missed notification is reconciled by worker; stale/failed server check never extends verification lease', async () => {
  const f = await fixture(), a = await f.actor(), ref = f.purchase(a);
  await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  f.verifier.values.get(ref)!.state = 'revoked'; time += 65000;
  await f.service.background('maintenance', {});
  assert.equal((await f.call(a, 'status')).status, 'revoked');
  f.verifier.values.delete(ref); time += 121000;
  await assert.rejects(f.call(a, 'status'));
});
test('account deletion removes reusable purchase data, preserves B and refuses re-registration transfer', async () => {
  const f = await fixture(), a = await f.actor(), b = await f.actor(), ref = f.purchase(a);
  await f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  await db.doc(`${accounts.scope}/accounts/${a.uid}`).update({ status: 'deleting', generation: 1 });
  await detachBillingData(db, accounts.scope, a.uid);
  await db.recursiveDelete(db.doc(`${accounts.scope}/accounts/${a.uid}`));
  const row = (await db.doc(`${accounts.scope}/billingLedger/${sha256(`play\0${ref}`)}`).get()).data()!;
  assert.equal(row.owner, undefined); assert.equal(row.cipher, undefined); assert.equal(row.orphaned, true);
  assert.equal((await db.doc(`${accounts.scope}/accounts/${b.uid}`).get()).exists, true);
  await assert.rejects(f.call(a, 'status'), ApiError);
  f.verifier.values.get(ref)!.binding = b.binding;
  await assert.rejects(f.call(b, 'verify', { productId: 'fixture_premium', reference: ref }), ApiError);
});
test('family lease excludes concurrent refresh and an account change during official verification blocks delivery', async () => {
  const f = await fixture(), a = await f.actor(), ref = f.purchase(a);
  let release!: () => void; f.verifier.gate = new Promise<void>(resolve => { release = resolve; });
  let entered!: () => void; const enteredGate = new Promise<void>(resolve => { entered = resolve; });
  f.verifier.entered = entered;
  const first = f.call(a, 'verify', { productId: 'fixture_premium', reference: ref });
  await enteredGate;
  await assert.rejects(f.call(a, 'verify', { productId: 'fixture_premium', reference: ref }), ApiError);
  await db.doc(`${accounts.scope}/accounts/${a.uid}`).update({ status: 'deleting' });
  release(); await assert.rejects(first, ApiError); assert.equal(f.verifier.acks, 0);
});
test('Apple and Play bindings/entitlements are distinct even for the same verified internal account', async () => {
  const f = await fixture(), a = await f.actor();
  const iosSessions = { verify: async (token: string, proof?: string) => ({ ...await sessions.verify(token, proof), store: 'app-store' as const }) };
  const ios = new BillingService(config, settings, db, accounts, iosSessions, f.verifier, now);
  const invoke = (action: string, body: unknown = {}) => ios.handle(action, body, `Bearer ${a.token}`, undefined, a.handle);
  const binding = (await invoke('intent', { period: 'monthly' })).binding as string;
  assert.notEqual(binding, a.binding);
  f.verifier.values.set('123456789', { store: 'app-store', reference: '123456789', binding,
    product: 'fixture_ios_month', period: 'monthly', state: 'active', autoRenew: true, validUntilMs: time + 86400000, acknowledged: true });
  await invoke('verify', { productId: 'fixture_ios_month', reference: '123456789' });
  assert.equal((await invoke('status')).status, 'active');
  assert.equal((await f.call(a, 'status')).status, 'unverified');
});
test('first purchase can be fulfilled from an authenticated notification after app closure, only for a prior server binding', async () => {
  const f = await fixture(), a = await f.actor(), ref = f.purchase(a);
  await f.service.background('play', { reference: ref });
  assert.equal((await f.call(a, 'status')).status, 'active'); assert.equal(f.verifier.acks, 1);
  const unknown = 'fictional_unbound_store_reference';
  f.verifier.values.set(unknown, { ...f.verifier.values.get(ref)!, reference: unknown,
    binding: '22222222-2222-4222-a222-222222222222', acknowledged: false });
  await f.service.background('play', { reference: unknown });
  assert.equal((await db.doc(`${accounts.scope}/billingLedger/${sha256(`play\0${unknown}`)}`).get()).exists, false);
});
test('per-account purchase API limits requests without blocking other owners permanently', async () => {
  const f = await fixture(), a = await f.actor();
  for (let i = 0; i < 29; i++) await f.call(a, 'status');
  await assert.rejects(f.call(a, 'status'), (e: unknown) => e instanceof ApiError && e.status === 429);
  const b = await f.actor(); assert.equal((await f.call(b, 'status')).status, 'unverified');
  time += 61000; assert.equal((await f.call(a, 'status')).status, 'unverified');
});
