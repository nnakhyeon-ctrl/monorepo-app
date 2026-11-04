import { randomBytes, timingSafeEqual } from 'node:crypto';
import type { Auth } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { ApiError, bearer, recent, type Identity, type RuntimeConfig, FirebaseSessionVerifier } from './security.js';
import { AccountRepository, providerKey } from './repository.js';
import { object } from './validation.js';
import { MailLimiter } from './email.js';
import { sha256, type SocialConfig, type SocialChallenge, type SocialProvider, type SocialProofVerifier } from './social-proof.js';

const random = () => randomBytes(32).toString('base64url');
const same = (a: string, b: string) => timingSafeEqual(Buffer.from(sha256(a)), Buffer.from(b));
const validHandle = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value);

export class SocialService {
  private readonly limits: MailLimiter;
  constructor(private readonly config: RuntimeConfig, private readonly social: SocialConfig,
    private readonly auth: Auth, private readonly db: Firestore, private readonly accounts: AccountRepository,
    private readonly sessions: FirebaseSessionVerifier, private readonly upstream: SocialProofVerifier,
    private readonly secret: string | undefined, private readonly now = Date.now) {
    this.limits = new MailLimiter(db, accounts.scope,
      config.mode === 'emulator' ? 'demo-social-rate-key-not-for-cloud' : secret ?? 'unconfigured', now);
  }
  private ready(provider: SocialProvider, platform: Identity['store']) {
    if (!this.social[provider] || (this.config.mode === 'cloud' && (this.secret?.length ?? 0) < 32) ||
        (provider === 'apple' && platform !== 'app-store') ||
        (provider === 'google' && !(platform === 'play' ? this.social.google!.androidClients : this.social.google!.iosClients).length)) {
      throw new ApiError(503, 'social_setup_required');
    }
  }
  private async owner(authorization: unknown, proof: string | undefined, handle: string | undefined, fresh = true) {
    const identity = await this.sessions.verify(bearer(authorization), proof);
    if (fresh) recent(identity, this.now());
    await this.accounts.read(identity, handle ?? '', 'progress');
    const account = (await this.db.doc(`${this.accounts.scope}/accounts/${identity.uid}`).get()).data();
    return { identity, epoch: account?.authEpoch ?? 0 };
  }
  async handle(path: string, body: unknown, authorization: unknown, proof: string | undefined,
      handle: string | undefined, source: string) {
    const platform = await this.sessions.checkApp(proof);
    if (path === 'policy') return { enabled: (['google', 'kakao', 'apple'] as const).filter((provider) => {
      try { this.ready(provider, platform); return true; } catch (_) { return false; }
    }) };
    if (!await this.limits.allow(source, `social:${source}`, 'social', 0, 15)) throw new ApiError(429, 'try_later');
    if (path === 'begin') {
      const p = object(body, ['provider', 'intent']);
      if (!['google', 'kakao', 'apple'].includes(String(p.provider)) || !['signin', 'link', 'reauth'].includes(String(p.intent))) {
        throw new ApiError(400, 'invalid_input');
      }
      const provider = p.provider as SocialProvider;
      this.ready(provider, platform);
      const owner = p.intent !== 'signin' ? await this.owner(authorization, proof, handle, p.intent === 'link') : null;
      const challengeId = random(), state = random(), nonce = random(), createdAtMs = this.now();
      await this.db.doc(`${this.accounts.scope}/socialChallenges/${challengeId}`).create({
        provider, platform, intent: p.intent, nonceDigest: sha256(nonce), stateDigest: sha256(state),
        createdAtMs, expiresAtMs: createdAtMs + 300000, consumed: false,
        uid: owner?.identity.uid ?? null, authEpoch: owner?.epoch ?? null,
      });
      return { challengeId, state, nonce, expiresAtMs: createdAtMs + 300000 };
    }
    if (path !== 'complete') throw new ApiError(404, 'operation_not_available');
    const p = object(body, ['challengeId', 'state', 'proof']);
    if (!validHandle(p.challengeId) || !validHandle(p.state)) throw new ApiError(400, 'invalid_challenge');
    const ref = this.db.doc(`${this.accounts.scope}/socialChallenges/${p.challengeId}`);
    const challenge = (await ref.get()).data();
    if (!challenge || challenge.platform !== platform || challenge.consumed || challenge.expiresAtMs <= this.now() ||
        !same(p.state, challenge.stateDigest)) throw new ApiError(401, 'invalid_challenge');
    this.ready(challenge.provider, platform);
    const owner = challenge.intent !== 'signin' ? await this.owner(authorization, proof, handle, challenge.intent === 'link') : null;
    if (owner && (owner.identity.uid !== challenge.uid || owner.epoch !== challenge.authEpoch)) throw new ApiError(401, 'invalid_challenge');
    const upstream = await this.upstream.verify(object(p.proof, ['kind', 'idToken', 'accessToken']), challenge as SocialChallenge);
    const mapping = this.db.doc(`${this.accounts.scope}/providers/${providerKey(upstream.provider, upstream.subject)}`);
    const candidate = `social_${randomBytes(18).toString('base64url')}`;
    const selected = await this.db.runTransaction(async (tx) => {
      const existing = (await tx.get(mapping)).data();
      if (challenge.intent === 'reauth' && (!existing || existing.uid !== owner?.identity.uid)) {
        throw new ApiError(409, 'provider_conflict');
      }
      if (existing && owner && existing.uid !== owner.identity.uid) throw new ApiError(409, 'provider_conflict');
      const uid = existing?.uid ?? owner?.identity.uid ?? candidate;
      const [a, removed] = await tx.getAll(this.db.doc(`${this.accounts.scope}/accounts/${uid}`),
        this.db.doc(`${this.accounts.scope}/deletedAccounts/${sha256(uid)}`));
      const account = a!.data();
      if (removed!.exists) throw new ApiError(403, 'account_unavailable');
      if (account && account.status !== 'active') throw new ApiError(403, 'account_unavailable');
      if (!existing) tx.create(mapping, { uid, ...upstream, provisioning: !owner, createdAtMs: this.now() });
      return { uid: uid as string, mayCreate: existing ? existing.provisioning === true : !owner };
    });
    try {
      if ((await this.auth.getUser(selected.uid)).disabled) throw new ApiError(401, 'invalid_session');
    }
    catch (error) {
      if ((error as { code?: string }).code !== 'auth/user-not-found' || !selected.mayCreate) throw new ApiError(401, 'invalid_session');
      try { await this.auth.createUser({ uid: selected.uid }); } catch (creation) {
        if ((creation as { code?: string }).code !== 'auth/uid-already-exists') throw new ApiError(503, 'social_unavailable');
      }
    }
    const grantId = random();
    await this.db.runTransaction(async (tx) => {
      const accountRef = this.db.doc(`${this.accounts.scope}/accounts/${selected.uid}`);
      const [latest, accountSnapshot, providerSnapshot] = await tx.getAll(ref, accountRef, mapping);
      const c = latest!.data(), account = accountSnapshot!.data();
      if (!c || c.consumed || c.expiresAtMs <= this.now() || providerSnapshot!.data()?.uid !== selected.uid) throw new ApiError(401, 'invalid_challenge');
      if (account && account.status !== 'active') throw new ApiError(403, 'account_unavailable');
      if (owner && (account?.authEpoch ?? 0) !== challenge.authEpoch) throw new ApiError(401, 'invalid_session');
      if (!account) tx.create(accountRef, { status: 'active', authEpoch: 0, generation: 0, startAfterIat: -1, createdAtMs: this.now() });
      tx.update(ref, { consumed: true });
      tx.update(mapping, { provisioning: false });
      tx.create(this.db.doc(`${this.accounts.scope}/socialGrants/${grantId}`), {
        uid: selected.uid, ...upstream, authEpoch: account?.authEpoch ?? 0,
        createdAtMs: this.now(), expiresAtMs: this.now() + 3600000,
      });
    });
    // No email/profile import and no Firebase trusted-email linking.
    const customToken = await this.auth.createCustomToken(selected.uid, { azSocialGrant: grantId });
    return { uid: selected.uid, customToken, linked: challenge.intent === 'link' };
  }
}
