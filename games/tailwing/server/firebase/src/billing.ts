import { createCipheriv, createDecipheriv, randomBytes, randomUUID } from 'node:crypto';
import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { ApiError, bearer, type Identity, type RuntimeConfig, type SessionVerifier } from './security.js';
import { AccountRepository } from './repository.js';
import { subscriptionContent } from './content-catalog.js';
import { object } from './validation.js';
import { sha256 } from './social-proof.js';
import { permits, type BillingConfig, type Store, type StoreVerifier, type VerifiedSubscription, type Period } from './billing-store.js';

const leaseMs = 120000;
const hash = (store: Store, value: string) => sha256(`${store}\0${value}`);
export function sealReference(reference: string, key: Buffer, aad: string): string {
  const nonce = randomBytes(12), cipher = createCipheriv('aes-256-gcm', key, nonce);
  cipher.setAAD(Buffer.from(aad));
  const data = Buffer.concat([cipher.update(reference, 'utf8'), cipher.final()]);
  return Buffer.concat([nonce, cipher.getAuthTag(), data]).toString('base64');
}
export function openReference(value: string, key: Buffer, aad: string): string {
  const data = Buffer.from(value, 'base64'), decipher = createDecipheriv('aes-256-gcm', key, data.subarray(0, 12));
  decipher.setAAD(Buffer.from(aad)); decipher.setAuthTag(data.subarray(12, 28));
  return Buffer.concat([decipher.update(data.subarray(28)), decipher.final()]).toString('utf8');
}
// Called during account cleanup. Keep only a pseudonymous ownership tombstone;
// no UID, binding, raw store reference or reusable encrypted credential remains.
export async function detachBillingData(db: Firestore, scope: string, uid: string) {
  while (true) {
    const bindings = await db.collection(`${scope}/billingBindings`).where('owner', '==', uid).limit(100).get();
    if (bindings.empty) break;
    const batch = db.batch(); for (const binding of bindings.docs) batch.delete(binding.ref); await batch.commit();
  }
  while (true) {
    const rows = await db.collection(`${scope}/billingLedger`).where('owner', '==', uid).limit(100).get();
    if (rows.empty) return;
    const batch = db.batch();
    for (const row of rows.docs) batch.update(row.ref, { owner: FieldValue.delete(), cipher: FieldValue.delete(),
      bindingHash: FieldValue.delete(), orphaned: true, acknowledged: false, state: 'revoked', validUntilMs: 0,
      nextCheckAtMs: Number.MAX_SAFE_INTEGER });
    await batch.commit();
  }
}

export class BillingService {
  constructor(private readonly runtime: RuntimeConfig, private readonly config: BillingConfig,
    private readonly db: Firestore, private readonly accounts: AccountRepository,
    private readonly sessions: SessionVerifier, private readonly verifier: StoreVerifier, private readonly now = Date.now) {}
  private ready(store: Store) {
    if (!this.config.ready || this.config.sealKey?.length !== 32 ||
        !(store === 'play' ? this.config.play : this.config.apple)) throw new ApiError(503, 'billing_setup_required');
  }
  private account(uid: string) { return this.db.doc(`${this.accounts.scope}/accounts/${uid}`); }
  private binding(uid: string, store: Store) { return this.account(uid).collection('private').doc(`billing_${store}`); }
  private record(key: string) { return this.db.doc(`${this.accounts.scope}/billingLedger/${key}`); }
  private owner(uid: string, store: Store) { return sha256(`${this.runtime.projectId}\0${this.runtime.environment}\0${store}\0${uid}`); }
  private products(store: Store) {
    if (store === 'play' && this.config.play) return (['monthly', 'annual'] as const).map(period =>
      ({ period, productId: this.config.play!.product, basePlanId: this.config.play![period] }));
    if (store === 'app-store' && this.config.apple) return (['monthly', 'annual'] as const).map(period =>
      ({ period, productId: this.config.apple![period] }));
    return [];
  }
  async handle(path: string, body: unknown, authorization: unknown, proof: string | undefined, handle = ''): Promise<Record<string, unknown>> {
    if (path === 'policy') return { ready: this.config.ready, play: this.products('play'), apple: this.products('app-store'),
      offlinePremium: false, purchaseType: 'auto-renewable-subscription', planChange: false };
    const identity = await this.sessions.verify(bearer(authorization), proof);
    const generation = await this.db.runTransaction(tx => this.accounts.authorize(tx, identity, handle));
    const ready = this.config.ready && !!(identity.store === 'play' ? this.config.play : this.config.apple);
    if (path === 'status' && !ready) return { ready: false, status: 'unverified', verified: false, owned: [], store: identity.store, products: [],
      serverNowMs: this.now(), validUntilMs: null, leaseUntilMs: null };
    this.ready(identity.store);
    await this.db.runTransaction(async tx => {
      await this.accounts.authorize(tx, identity, handle);
      const ref = this.account(identity.uid).collection('billingLimits').doc(`${identity.store}_${Math.floor(this.now() / 60000)}`);
      const count = (await tx.get(ref)).data()?.count ?? 0;
      if (count >= 30) throw new ApiError(429, 'billing_try_later');
      tx.set(ref, { count: count + 1, expiresAt: Timestamp.fromMillis(this.now() + 900000) });
    });
    if (path === 'status') {
      await this.refreshOwned(identity.uid, identity.store, generation);
      return this.status(identity, handle);
    }
    if (path === 'intent') {
      const b = object(body, ['period']);
      if (!['monthly', 'annual'].includes(b.period as string)) throw new ApiError(400, 'invalid_input');
      await this.refreshOwned(identity.uid, identity.store, generation);
      const current = await this.status(identity, handle);
      if (current.status === 'active' || current.status === 'canceled' || current.status === 'grace' || current.status === 'pending') {
        throw new ApiError(409, 'subscription_already_exists');
      }
      if (current.status === 'unverified' && current.hasPurchases === true) throw new ApiError(503, 'billing_verification_failed');
      const binding = await this.db.runTransaction(async tx => {
        await this.accounts.authorize(tx, identity, handle);
        const ref = this.binding(identity.uid, identity.store), old = (await tx.get(ref)).data();
        if (old && old.generation !== generation) throw new ApiError(409, 'purchase_owner_conflict');
        const value = old?.binding as string | undefined ?? randomUUID();
        const index = this.db.doc(`${this.accounts.scope}/billingBindings/${hash(identity.store, value)}`);
        const previous = (await tx.get(index)).data();
        if (previous && (previous.owner !== identity.uid || previous.generation !== generation || previous.store !== identity.store)) {
          throw new ApiError(409, 'purchase_owner_conflict');
        }
        if (!old) tx.create(ref, { binding: value, generation, store: identity.store });
        if (!previous) tx.create(index, { owner: identity.uid, generation, store: identity.store });
        return value;
      });
      return { binding, store: identity.store, product: this.products(identity.store).find(p => p.period === b.period) };
    }
    if (path === 'verify') {
      const b = object(body, ['productId', 'reference']);
      if (typeof b.reference !== 'string' || b.reference.length > 8192 || typeof b.productId !== 'string' ||
        !this.products(identity.store).some(p => p.productId === b.productId)) throw new ApiError(400, 'invalid_purchase');
      const binding = (await this.binding(identity.uid, identity.store).get()).data();
      if (!binding?.binding || binding.generation !== generation) throw new ApiError(409, 'purchase_owner_conflict');
      const value = await this.reconcile(identity.uid, identity.store, generation, binding.binding as string,
        b.reference, b.productId);
      const entitlement = await this.status(identity, handle);
      return { verified: true, finish: value.state !== 'pending', entitlement };
    }
    throw new ApiError(404, 'operation_not_available');
  }
  private async status(identity: Identity, handle: string): Promise<Record<string, unknown>> {
    return this.db.runTransaction(async tx => {
      await this.accounts.authorize(tx, identity, handle);
      const records = await tx.get(this.account(identity.uid).collection('billing').where('store', '==', identity.store));
      const values = records.docs.map(d => d.data()).filter(v => v.owner === identity.uid &&
        v.environment === this.runtime.environment && v.app === 'airzero-strike' && v.verified === true && !v.replaced);
      const allowed = values.filter(v => v.acknowledged === true && v.checkedAtMs + leaseMs > this.now() && permits(v as VerifiedSubscription, this.now()))
        .sort((a, b) => b.validUntilMs - a.validUntilMs)[0];
      const latest = values.sort((a, b) => b.checkedAtMs - a.checkedAtMs)[0];
      const v = allowed ?? latest;
      const state = allowed ? allowed.state : v && v.checkedAtMs + leaseMs > this.now() ?
        (['active', 'canceled', 'grace'].includes(v.state) ? (v.validUntilMs <= this.now() ? 'expired' : 'unverified') : v.state) : 'unverified';
      return { ready: true, verified: !!v && v.checkedAtMs + leaseMs > this.now(), status: state,
        store: identity.store, products: this.products(identity.store), serverNowMs: this.now(),
        validUntilMs: v?.validUntilMs ?? null, leaseUntilMs: allowed ? Math.min(allowed.validUntilMs, allowed.checkedAtMs + leaseMs) : null,
        autoRenew: v?.autoRenew ?? false, period: v?.period ?? null, hasPurchases: values.length > 0,
        owned: allowed ? [...subscriptionContent] : [] };
    });
  }
  private async refreshOwned(uid: string, store: Store, generation: number) {
    const rows = await this.db.collection(`${this.accounts.scope}/billingLedger`).where('owner', '==', uid).get();
    for (const row of rows.docs) {
      const v = row.data();
      if (v.store !== store || v.orphaned || v.replaced || v.generation !== generation || v.checkedAtMs + 60000 > this.now()) continue;
      if (typeof v.cipher !== 'string') throw new ApiError(503, 'billing_verification_failed');
      const binding = (await this.binding(uid, store).get()).data()?.binding;
      if (typeof binding !== 'string') throw new ApiError(409, 'purchase_owner_conflict');
      await this.reconcile(uid, store, generation, binding, openReference(v.cipher, this.config.sealKey!, `${this.accounts.scope}/${row.id}`));
    }
  }
  private async reconcile(uid: string, store: Store, generation: number, binding: string, raw: string, product?: string): Promise<VerifiedSubscription> {
    this.ready(store);
    const reference = await this.verifier.resolve(store, raw), key = hash(store, reference), ref = this.record(key);
    const lock = this.db.doc(`${this.accounts.scope}/billingLocks/${key}`), lease = randomUUID();
    await this.db.runTransaction(async tx => {
      const current = (await tx.get(lock)).data();
      if (current?.untilMs > this.now()) throw new ApiError(409, 'billing_busy');
      tx.set(lock, { lease, untilMs: this.now() + 60000 });
    });
    try {
      // Query canonical state while holding a family lease. Notification order,
      // client timestamps and old transaction callbacks are never state versions.
      const v = await this.verifier.verify(store, reference);
      if (v.store !== store || v.reference !== reference || v.binding !== binding ||
        !this.products(store).some(p => p.productId === v.product && p.period === v.period) ||
        (product !== undefined && product !== v.product)) throw new ApiError(409, 'purchase_owner_conflict');
      const previous = v.linkedReference ? this.record(hash(store, v.linkedReference)) : null;
      await this.db.runTransaction(async tx => {
        const [a, l, r, old] = await tx.getAll(this.account(uid), lock, ref,
          previous ?? this.account(uid));
        const account = a!.data(), existing = r!.data(), previousValue = old!.data();
        if (!account || account.status !== 'active' || account.generation !== generation) throw new ApiError(401, 'invalid_session');
        if (l!.data()?.lease !== lease || l!.data()!.untilMs <= this.now()) throw new ApiError(409, 'billing_busy');
        const ownerHash = this.owner(uid, store);
        if (existing && (existing.ownerHash !== ownerHash || existing.orphaned || existing.replaced) ||
          previous && previousValue && (previousValue.ownerHash !== ownerHash || previousValue.orphaned)) throw new ApiError(409, 'purchase_owner_conflict');
        const row = { app: 'airzero-strike', environment: this.runtime.environment, store, owner: uid, ownerHash, generation,
          bindingHash: sha256(binding), product: v.product, period: v.period, state: v.state, validUntilMs: v.validUntilMs,
          autoRenew: v.autoRenew, acknowledged: v.acknowledged, verified: true, checkedAtMs: this.now(),
          nextCheckAtMs: this.now() + (v.acknowledged ? 60000 : 15000), orphaned: false,
          cipher: sealReference(reference, this.config.sealKey!, `${this.accounts.scope}/${key}`) };
        tx.set(ref, row);
        const { cipher: _cipher, bindingHash: _binding, ownerHash: _owner, ...owned } = row;
        tx.set(this.account(uid).collection('billing').doc(key), owned);
        if (previous && previousValue) {
          tx.update(previous, { replaced: true, nextCheckAtMs: Number.MAX_SAFE_INTEGER });
          tx.set(this.account(uid).collection('billing').doc(previous.id), { replaced: true }, { merge: true });
        }
      });
      // Persist verified delivery before Google acknowledgement. A failed ack
      // leaves a retryable server record, never a client-side unlock.
      if (!v.acknowledged && permits(v, this.now())) {
        await this.verifier.acknowledge(v);
        await this.db.runTransaction(async tx => {
          const [a, l, r] = await tx.getAll(this.account(uid), lock, ref);
          if (a!.data()?.status !== 'active' || a!.data()?.generation !== generation ||
              l!.data()?.lease !== lease || l!.data()!.untilMs <= this.now() || r!.data()?.orphaned) throw new ApiError(401, 'invalid_session');
          tx.update(ref, { acknowledged: true });
          tx.update(this.account(uid).collection('billing').doc(key), { acknowledged: true });
        });
        v.acknowledged = true;
      }
      return v;
    } finally {
      await this.db.runTransaction(async tx => {
        if ((await tx.get(lock)).data()?.lease === lease) tx.delete(lock);
      });
    }
  }
  async background(path: string, body: unknown, authorization?: string): Promise<Record<string, unknown>> {
    if (!this.config.ready) throw new ApiError(503, 'billing_setup_required');
    if (path === 'maintenance') {
      await this.verifier.worker(authorization);
      const rows = await this.db.collection(`${this.accounts.scope}/billingLedger`).where('nextCheckAtMs', '<=', this.now()).limit(20).get();
      let failures = 0;
      for (const row of rows.docs) {
        try { await this.refreshRecord(row.id); }
        catch { failures++; await row.ref.update({ nextCheckAtMs: this.now() + 60000 }); }
      }
      return { accepted: true, failures }; // A failing store record must not starve other owners.
    }
    const store = path === 'play' ? 'play' : path === 'apple' ? 'app-store' : null;
    if (!store) throw new ApiError(404, 'operation_not_available');
    this.ready(store);
    const reference = await this.verifier.notification(store, body, authorization);
    if (!reference) return { accepted: true };
    const canonical = await this.verifier.resolve(store, reference);
    const key = hash(store, canonical);
    if (!(await this.record(key).get()).exists) {
      const official = await this.verifier.verify(store, canonical);
      if (official.store !== store || official.reference !== canonical) throw new ApiError(403, 'purchase_scope_denied');
      const index = (await this.db.doc(`${this.accounts.scope}/billingBindings/${hash(store, official.binding)}`).get()).data();
      if (index?.owner && index.store === store) {
        const binding = (await this.binding(index.owner, store).get()).data();
        if (binding?.binding === official.binding && binding.generation === index.generation) {
          await this.reconcile(index.owner, store, index.generation, official.binding, canonical);
        }
      }
      return { accepted: true };
    }
    await this.refreshRecord(key);
    return { accepted: true }; // Unknown/unbound subscriptions never gain an owner.
  }
  private async refreshRecord(key: string) {
    const row = (await this.record(key).get()).data();
    if (!row || row.orphaned || row.replaced || typeof row.owner !== 'string' || typeof row.cipher !== 'string') return;
    const binding = (await this.binding(row.owner, row.store).get()).data()?.binding;
    if (typeof binding !== 'string') return;
    await this.reconcile(row.owner, row.store, row.generation, binding,
      openReference(row.cipher, this.config.sealKey!, `${this.accounts.scope}/${key}`));
  }
}
