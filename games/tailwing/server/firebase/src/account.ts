import { randomBytes } from 'node:crypto';
import type { Auth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { ApiError, bearer, recent, type RuntimeConfig, FirebaseSessionVerifier } from './security.js';
import { AccountRepository } from './repository.js';
import { object } from './validation.js';
import { sha256 } from './social-proof.js';
import { MailLimiter } from './email.js';
import { detachBillingData } from './billing.js';

export const deletionNotice = 'airzero-account-delete-v1';
const day = 86400000;
const receipt = (value: unknown): string => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(value)) throw new ApiError(400, 'invalid_deletion_request');
  return value;
};
const missingUser = (error: unknown) => (error as { code?: string }).code === 'auth/user-not-found';

/** Only the owning app/environment is traversed. Receipts authorize continuing
 * an ALREADY confirmed deletion, never profile access or a new deletion. */
export class AccountService {
  private readonly limiter: MailLimiter;
  constructor(private readonly config: RuntimeConfig, private readonly auth: Auth,
    private readonly db: Firestore, private readonly accounts: AccountRepository,
    private readonly sessions: FirebaseSessionVerifier, private readonly env: NodeJS.ProcessEnv,
    private readonly now = Date.now, private readonly checkpoint: (step: string) => Promise<void> = async () => {}) {
    this.limiter = new MailLimiter(db, accounts.scope,
      config.mode === 'emulator' ? 'demo-account-rate-not-for-cloud' : env.AIRZERO_ACCOUNT_RATE_SECRET ?? 'unconfigured', now);
  }
  private ready(): boolean {
    return this.config.mode === 'emulator' || (this.env.AIRZERO_ACCOUNT_DELETION_READY === 'true' &&
      this.env.AIRZERO_ACCOUNT_CLEANUP_READY === 'true' &&
      (this.env.AIRZERO_ACCOUNT_RATE_SECRET?.length ?? 0) >= 32);
  }
  private job(value: unknown) { return this.db.doc(`${this.accounts.scope}/deletionJobs/${sha256(receipt(value))}`); }
  async handle(path: string, body: unknown, authorization: unknown, proof: string | undefined,
    handle: string | undefined, source: string): Promise<Record<string, unknown>> {
    if (path === 'policy') return { ready: this.ready(), noticeVersion: deletionNotice,
      preparedLifetimeSeconds: 300, receiptRetentionDays: 7, immediateChoice: true,
      deletes: ['account', 'progress', 'preferences', 'loadout-cache', 'provider-mappings', 'sessions', 'entitlement-cache'],
      subscriptionCancellation: false, providerAccountDeletion: false };
    await this.sessions.checkApp(proof);
    if (path === 'profile') {
      const identity = await this.sessions.verify(bearer(authorization), proof);
      return this.accounts.profile(identity, handle ?? '');
    }
    if (!this.ready()) throw new ApiError(503, 'account_setup_required');
    if (!await this.limiter.allow(source, `deletion:${source}`, 'account', 0, 15)) throw new ApiError(429, 'try_later');
    if (path === 'resume') {
      const p = object(body, ['receipt']);
      return this.process(receipt(p.receipt));
    }
    const identity = await this.sessions.verify(bearer(authorization), proof);
    recent(identity, this.now());
    const p = object(body, path === 'prepare' ? ['receipt'] : ['receipt', 'confirmed', 'noticeVersion']);
    const ref = this.job(p.receipt);
    if (path === 'prepare') {
      return this.db.runTransaction(async (tx) => {
        await this.accounts.authorize(tx, identity, handle ?? '');
        const old = (await tx.get(ref)).data();
        if (old && (old.uid !== identity.uid || old.status !== 'prepared')) throw new ApiError(409, 'invalid_deletion_request');
        if (old && old.expiresAtMs <= this.now()) throw new ApiError(410, 'deletion_request_expired');
        if (!old) tx.create(ref, { uid: identity.uid, status: 'prepared', createdAtMs: this.now(),
          expiresAtMs: this.now() + 300000, expiresAt: Timestamp.fromMillis(this.now() + 300000) });
        return { status: 'prepared', noticeVersion: deletionNotice, expiresAtMs: old?.expiresAtMs ?? this.now() + 300000 };
      });
    }
    if (path !== 'commit') throw new ApiError(404, 'operation_not_available');
    if (p.confirmed !== true || p.noticeVersion !== deletionNotice) throw new ApiError(409, 'confirmation_required');
    await this.db.runTransaction(async (tx) => {
      const generation = await this.accounts.authorize(tx, identity, handle ?? '');
      const [j, a] = await tx.getAll(ref, this.db.doc(`${this.accounts.scope}/accounts/${identity.uid}`));
      const job = j!.data(), account = a!.data();
      if (!job || job.uid !== identity.uid || job.status !== 'prepared') throw new ApiError(409, 'invalid_deletion_request');
      if (job.expiresAtMs <= this.now()) throw new ApiError(410, 'deletion_request_expired');
      // Gates fail as soon as this transaction commits, before slow cleanup.
      tx.update(a!.ref, { status: 'deleting', generation: generation + 1, authEpoch: (account?.authEpoch ?? 0) + 1 });
      tx.set(this.db.doc(`${this.accounts.scope}/deletedAccounts/${sha256(identity.uid)}`), {
        blockedAtMs: this.now(), expiresAt: Timestamp.fromMillis(this.now() + 7 * day) });
      tx.update(ref, { status: 'pending', noticeVersion: deletionNotice, acceptedAtMs: this.now(),
        expiresAtMs: this.now() + 7 * day, expiresAt: FieldValue.delete() });
    });
    return this.process(receipt(p.receipt));
  }
  private async removeOwned(collection: string, uid: string): Promise<void> {
    while (true) {
      const page = await this.db.collection(`${this.accounts.scope}/${collection}`).where('uid', '==', uid).limit(200).get();
      if (page.empty) return;
      const batch = this.db.batch();
      for (const doc of page.docs) batch.delete(doc.ref);
      await batch.commit();
    }
  }
  async process(value: string): Promise<Record<string, unknown>> {
    return this.processJob(this.job(value), false);
  }
  /** Server worker entry point. Never exposed as an unauthenticated HTTP job runner.
   * Pending jobs have no TTL: failed cleanup cannot silently discard user data. */
  async maintenance(): Promise<void> {
    if (!this.ready()) throw new ApiError(503, 'account_setup_required');
    const jobs = await this.db.collection(`${this.accounts.scope}/deletionJobs`).where('status', '==', 'pending').limit(20).get();
    for (const job of jobs.docs) await this.processJob(job.ref, true);
  }
  private async processJob(ref: FirebaseFirestore.DocumentReference, maintenance: boolean): Promise<Record<string, unknown>> {
    const lease = randomBytes(32).toString('base64url');
    const acquired = await this.db.runTransaction(async (tx) => {
      const job = (await tx.get(ref)).data();
      if (!job || (!maintenance && job.expiresAtMs <= this.now())) throw new ApiError(410, 'deletion_request_expired');
      if (job.status === 'complete' || job.status === 'prepared') return { status: job.status as string };
      if (job.status !== 'pending' || typeof job.uid !== 'string') throw new ApiError(409, 'invalid_deletion_request');
      if (job.leaseUntilMs > this.now()) return { status: 'pending' };
      tx.update(ref, { lease, leaseUntilMs: this.now() + 60000 });
      return { status: 'acquired', uid: job.uid as string };
    });
    if (acquired.status !== 'acquired') return { status: acquired.status };
    const uid = acquired.uid!;
    try {
      try { await this.auth.updateUser(uid, { disabled: true }); await this.auth.revokeRefreshTokens(uid); }
      catch (error) { if (!missingUser(error)) throw error; }
      await this.checkpoint('disabled');
      // No collectionGroup/global user scan; never traverse another app.
      for (const name of ['sessions', 'providers', 'socialGrants', 'socialChallenges']) await this.removeOwned(name, uid);
      await this.db.doc(`${this.accounts.scope}/passwordAccounts/${uid}`).delete();
      await detachBillingData(this.db, this.accounts.scope, uid);
      await this.db.recursiveDelete(this.db.doc(`${this.accounts.scope}/accounts/${uid}`));
      await this.checkpoint('data-removed');
      try { await this.auth.deleteUser(uid); } catch (error) { if (!missingUser(error)) throw error; }
      await this.checkpoint('auth-removed');
      await this.db.runTransaction(async (tx) => {
        const current = (await tx.get(ref)).data();
        if (current?.lease !== lease) throw new ApiError(409, 'deletion_busy');
        tx.update(ref, { status: 'complete', completedAtMs: this.now(), uid: FieldValue.delete(),
          expiresAt: Timestamp.fromMillis(this.now() + 7 * day),
          lease: FieldValue.delete(), leaseUntilMs: FieldValue.delete() });
      });
      return { status: 'complete' };
    } catch (_) {
      await this.db.runTransaction(async (tx) => {
        if ((await tx.get(ref)).data()?.lease === lease) tx.update(ref, { leaseUntilMs: 0 });
      });
      return { status: 'pending' }; // No raw exception, UID or provider token.
    }
  }
}
