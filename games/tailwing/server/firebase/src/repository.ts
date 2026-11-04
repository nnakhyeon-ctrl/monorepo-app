import { createHash, randomBytes } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { ApiError, appName, recent, type Identity, type RuntimeConfig } from './security.js';
import { defaultPreferences, type GuestProgress, type Preferences, unlocked } from './validation.js';
import { freeContent, subscriptionContent } from './content-catalog.js';

const digest = (value: string): string => createHash('sha256').update(value).digest('hex');
export const providerKey = (provider: string, subject: string): string => digest(`${provider}\0${subject}`);
type Reply = Record<string, unknown>;
const occupied = (progress: Reply): boolean => progress.imported === true ||
  !Array.isArray(progress.records) || progress.records.length > 0 || progress.unlocked !== 1;

export class AccountRepository {
  readonly scope: string;
  constructor(private readonly db: Firestore, config: RuntimeConfig, private readonly now = Date.now) {
    this.scope = `apps/${appName}/environments/${config.environment}`;
  }
  private account(uid: string) { return this.db.doc(`${this.scope}/accounts/${uid}`); }
  async resolveSocialGrant(uid: string, grantId: string, authTime: number) {
    if (!/^[A-Za-z0-9_-]{43}$/.test(grantId)) throw new ApiError(401, 'invalid_session');
    return this.db.runTransaction(async (tx) => {
      const [a, g] = await tx.getAll(this.account(uid), this.db.doc(`${this.scope}/socialGrants/${grantId}`));
      const account = a!.data(), grant = g!.data();
      if (!account || account.status !== 'active' || !grant || grant.uid !== uid ||
          grant.authEpoch !== (account.authEpoch ?? 0) || grant.expiresAtMs <= this.now() ||
          authTime * 1000 < grant.createdAtMs - 5000 || authTime * 1000 > grant.createdAtMs + 300000 ||
          !['google.com', 'kakao', 'apple.com'].includes(grant.provider)) throw new ApiError(401, 'invalid_session');
      const mapping = await tx.get(this.db.doc(`${this.scope}/providers/${providerKey(grant.provider, grant.subject)}`));
      if (mapping.data()?.uid !== uid) throw new ApiError(401, 'invalid_session');
      return { provider: grant.provider as string, subject: grant.subject as string };
    });
  }
  private data(uid: string, object: string) { return this.db.doc(`${this.scope}/accounts/${uid}/private/${object}`); }
  private session(handle: string) {
    if (!/^[A-Za-z0-9_-]{43}$/.test(handle)) throw new ApiError(401, 'invalid_session');
    return this.db.doc(`${this.scope}/sessions/${digest(handle)}`);
  }
  async start(identity: Identity): Promise<Reply> {
    const handle = randomBytes(32).toString('base64url');
    const expiresAt = Math.min(identity.expiresAt, this.now() + 3600000);
    const account = this.account(identity.uid);
    const providers = identity.providers.map((p) => this.db.doc(`${this.scope}/providers/${providerKey(p.provider, p.subject)}`));
    return this.db.runTransaction(async (tx) => {
      const grant = this.db.doc(`${this.scope}/passwordAccounts/${identity.uid}`);
      const snapshots = await tx.getAll(account, ...providers, grant,
        this.db.doc(`${this.scope}/deletedAccounts/${digest(identity.uid)}`));
      const old = snapshots[0]!.data();
      if (snapshots.at(-1)!.exists) throw new ApiError(403, 'account_unavailable');
      if (identity.signInProvider === 'password' && (identity.passwordRequiresApproval || identity.providers.some((p) => p.provider !== 'password')) &&
          snapshots[1 + providers.length]!.data()?.origin !== 'email-register') throw new ApiError(403, 'password_link_required');
      if (old && old.status !== 'active') throw new ApiError(403, 'account_unavailable');
      if (old && identity.issuedAt <= (old.startAfterIat ?? -1)) throw new ApiError(401, 'fresh_token_required');
      for (const snapshot of snapshots.slice(1, 1 + providers.length)) {
        if (snapshot.exists && snapshot.data()!.uid !== identity.uid) throw new ApiError(409, 'provider_conflict');
      }
      const generation = old?.generation ?? 0;
      tx.set(account, { status: 'active', generation, authEpoch: old?.authEpoch ?? 0, startAfterIat: old?.startAfterIat ?? -1,
        createdAtMs: old?.createdAtMs ?? this.now() });
      for (let i = 0; i < providers.length; i++) {
        const p = identity.providers[i]!;
        tx.set(providers[i]!, { uid: identity.uid, provider: p.provider, subject: p.subject });
      }
      tx.create(this.session(handle), { uid: identity.uid, generation, authEpoch: old?.authEpoch ?? 0,
        authTime: identity.authTime, expiresAtMs: expiresAt, revoked: false });
      return { uid: identity.uid, sessionHandle: handle, expiresAtMs: expiresAt, generation };
    });
  }
  private async gate(tx: Transaction, identity: Identity, handle: string): Promise<number> {
    const [a, s] = await tx.getAll(this.account(identity.uid), this.session(handle));
    const account = a!.data(), session = s!.data();
    if (!account || account.status !== 'active' || !session || session.uid !== identity.uid ||
        session.revoked || session.authEpoch !== (account.authEpoch ?? 0) || session.authTime !== identity.authTime ||
        session.generation !== account.generation || session.expiresAtMs <= this.now()) {
      throw new ApiError(401, 'invalid_session');
    }
    return account.generation as number;
  }
  async authorize(tx: Transaction, identity: Identity, handle: string): Promise<number> {
    return this.gate(tx, identity, handle);
  }
  async profile(identity: Identity, handle: string): Promise<Reply> {
    return this.db.runTransaction(async (tx) => {
      const generation = await this.gate(tx, identity, handle);
      const mappings = await tx.get(this.db.collection(`${this.scope}/providers`).where('uid', '==', identity.uid));
      return { uid: identity.uid, generation, status: 'active',
        providers: [...new Set(mappings.docs.map((d) => d.data().provider))]
          .filter((p) => ['password', 'google.com', 'kakao', 'apple.com'].includes(p)).sort() };
    });
  }
  async invalidateAuthSessions(uid: string): Promise<void> {
    await this.db.runTransaction(async (tx) => {
      const snapshot = await tx.get(this.account(uid));
      if (snapshot.exists) tx.update(snapshot.ref, { authEpoch: (snapshot.data()!.authEpoch ?? 0) + 1 });
    });
  }
  async markEmailPasswordAccount(uid: string): Promise<void> {
    await this.db.doc(`${this.scope}/passwordAccounts/${uid}`).create({ origin: 'email-register', createdAtMs: this.now() });
  }
  async allowsPasswordAccount(uid: string, providers: readonly string[]): Promise<boolean> {
    if (!providers.includes('password')) return false;
    if (providers.every((provider) => provider === 'password')) return true;
    const grant = await this.db.doc(`${this.scope}/passwordAccounts/${uid}`).get();
    return grant.data()?.origin === 'email-register';
  }
  async logout(identity: Identity, handle: string): Promise<Reply> {
    return this.db.runTransaction(async (tx) => {
      await this.gate(tx, identity, handle);
      const account = await tx.get(this.account(identity.uid));
      tx.update(this.session(handle), { revoked: true });
      // Current session closes immediately. Old ID tokens cannot reopen it;
      // another device's already-open session remains valid.
      tx.update(account.ref, { startAfterIat: Math.max(account.data()!.startAfterIat ?? -1, identity.issuedAt) });
      return { loggedOut: true };
    });
  }
  async read(identity: Identity, handle: string, kind: 'progress' | 'preferences'): Promise<Reply> {
    return this.db.runTransaction(async (tx) => {
      const generation = await this.gate(tx, identity, handle);
      const snapshot = await tx.get(this.data(identity.uid, kind));
      const data = snapshot.data();
      if (data && data.generation !== generation) throw new ApiError(409, 'generation_conflict');
      return { ...(data ?? (kind === 'progress'
        ? { schema: 1, revision: 0, imported: false, records: [], unlocked: 1 }
        : { revision: 0, settings: defaultPreferences })), generation };
    });
  }
  async preview(identity: Identity, handle: string): Promise<Reply> {
    const progress = await this.read(identity, handle, 'progress');
    return { decision: occupied(progress) ? 'conflict_keep_both' : 'empty_requires_confirmation',
      revision: progress.revision, generation: progress.generation };
  }
  private async mutate(identity: Identity, handle: string, operationId: string,
      payload: Reply, expectedRevision: number, expectedGeneration: number,
      kind: 'progress' | 'preferences', build: (old: Reply) => Reply): Promise<Reply> {
    const requestDigest = digest(JSON.stringify({ kind, expectedRevision, expectedGeneration, payload }));
    const receipt = this.db.doc(`${this.scope}/accounts/${identity.uid}/operations/${operationId}`);
    const target = this.data(identity.uid, kind);
    return this.db.runTransaction(async (tx) => {
      const generation = await this.gate(tx, identity, handle);
      if (generation !== expectedGeneration) throw new ApiError(409, 'generation_conflict');
      const [current, prior] = await tx.getAll(target, receipt);
      const old = current!.data() ?? { revision: 0, imported: false };
      if (current!.exists && old.generation !== generation) throw new ApiError(409, 'generation_conflict');
      if (prior!.exists) {
        if (prior!.data()!.digest !== requestDigest) throw new ApiError(409, 'operation_conflict');
        return prior!.data()!.reply as Reply;
      }
      if (old.revision !== expectedRevision) throw new ApiError(409, 'revision_conflict');
      const reply = { ...build(old), revision: expectedRevision + 1, generation };
      tx.set(target, reply);
      tx.create(receipt, { digest: requestDigest, reply, createdAtMs: this.now(), generation });
      return reply;
    });
  }
  async importGuest(identity: Identity, handle: string, operationId: string,
      expectedRevision: number, generation: number, guest: GuestProgress, confirmed: boolean): Promise<Reply> {
    recent(identity, this.now());
    if (!confirmed) throw new ApiError(409, 'confirmation_required');
    return this.mutate(identity, handle, operationId, { guest, confirmed }, expectedRevision, generation,
      'progress', (old) => {
        if (old.imported || (old.records !== undefined && occupied(old))) throw new ApiError(409, 'conflict_keep_both');
        return { schema: 1, imported: true, records: guest.records,
          unlocked: unlocked(guest.records), source: 'guest-import', validation: 'offline-unverified' };
      });
  }
  async savePreferences(identity: Identity, handle: string, operationId: string,
      revision: number, generation: number, settings: Preferences, reset = false): Promise<Reply> {
    if (reset) recent(identity, this.now());
    return this.mutate(identity, handle, operationId, { settings, reset }, revision, generation,
      'preferences', () => ({ settings }));
  }
  async entitlement(identity: Identity, handle: string): Promise<Reply> {
    return this.db.runTransaction(async (tx) => {
      await this.gate(tx, identity, handle);
      const r = (await tx.get(this.data(identity.uid, `entitlement_${identity.store}`))).data();
      const empty = { status: 'unverified', owned: [], validUntilMs: null };
      if (!r || r.app !== appName || r.owner !== identity.uid || r.environment !== this.scope.split('/').at(-1) ||
          r.store !== identity.store || r.source !== (identity.store === 'play' ? 'google-server' : 'apple-server') ||
          r.verified !== true || !['apple-server', 'google-server'].includes(r.source) ||
          !['active', 'canceled', 'grace'].includes(r.status) ||
          !Number.isSafeInteger(r.validUntilMs) || r.validUntilMs <= this.now()) return empty;
      return { status: r.status, validUntilMs: r.validUntilMs,
        owned: [...subscriptionContent] };
    });
  }
  async publicCatalog(): Promise<Reply> {
    const data = (await this.db.doc(`${this.scope}/public/catalog`).get()).data();
    if (!data || data.schema !== 1 || data.published !== true || Object.keys(data).some((k) =>
      !['schema', 'published', 'stages', 'freeContent'].includes(k)) ||
      !Array.isArray(data.stages) || data.stages.length > 15 ||
      data.stages.some((n: unknown) => !Number.isInteger(n) || Number(n) < 1 || Number(n) > 15) ||
      !Array.isArray(data.freeContent) || data.freeContent.some((id: unknown) =>
        !(freeContent as readonly string[]).includes(String(id)))) throw new ApiError(503, 'catalog_unavailable');
    return data;
  }
}
