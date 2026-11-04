import { createHash, createPrivateKey } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { GoogleAuth, OAuth2Client } from 'google-auth-library';
import { AppStoreServerAPIClient, SignedDataVerifier, Environment } from '@apple/app-store-server-library';
import { ApiError, type RuntimeConfig, type Identity } from './security.js';

export type Store = Identity['store'];
export type Period = 'monthly' | 'annual';
export type PaidState = 'active' | 'canceled' | 'grace' | 'pending' | 'hold' | 'paused' | 'expired' | 'revoked';
export interface BillingConfig {
  ready: boolean; sealKey?: Buffer;
  play?: { product: string; monthly: string; annual: string; pushEmail: string; pushAudience: string };
  apple?: { monthly: string; annual: string; group: string; appId: number; key: string; keyId: string; issuer: string };
  workerEmail?: string; workerAudience?: string;
}
export const billingPackage = 'com.example.raikeopeu2026.dev';
const id = (s = '') => /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(s);
export function loadBillingConfig(env: NodeJS.ProcessEnv): BillingConfig {
  if (env.AIRZERO_BILLING_READY !== 'true') return { ready: false };
  const key = Buffer.from(env.AIRZERO_BILLING_SEAL_KEY ?? '', 'base64');
  if (key.length !== 32 || env.AIRZERO_BILLING_NOTIFICATIONS_READY !== 'true' ||
      env.AIRZERO_BILLING_POLICY_READY !== 'true' || env.AIRZERO_BILLING_RETENTION_READY !== 'true') throw new Error('billing_security_not_configured');
  const result: BillingConfig = { ready: true, sealKey: key,
    workerEmail: env.AIRZERO_BILLING_WORKER_EMAIL, workerAudience: env.AIRZERO_BILLING_WORKER_AUDIENCE };
  const endpoint = `https://${env.AIRZERO_REGION}-${env.AIRZERO_PROJECT_ID}.cloudfunctions.net/api`;
  if (!/^airzero-billing-worker-[a-z0-9-]+@/.test(result.workerEmail ?? '') ||
      !result.workerEmail?.endsWith(`@${env.AIRZERO_PROJECT_ID}.iam.gserviceaccount.com`) ||
      result.workerAudience !== `${endpoint}/v1/billing/maintenance`) throw new Error('billing_worker_not_configured');
  if (env.AIRZERO_PLAY_SUBSCRIPTION_ID) {
    const p = { product: env.AIRZERO_PLAY_SUBSCRIPTION_ID, monthly: env.AIRZERO_PLAY_MONTHLY_PLAN ?? '',
      annual: env.AIRZERO_PLAY_ANNUAL_PLAN ?? '', pushEmail: env.AIRZERO_PLAY_PUSH_EMAIL ?? '',
      pushAudience: env.AIRZERO_PLAY_PUSH_AUDIENCE ?? '' };
    if (![p.product, p.monthly, p.annual].every(id) || p.monthly === p.annual ||
      !p.pushEmail.endsWith(`@${env.AIRZERO_PROJECT_ID}.iam.gserviceaccount.com`) ||
      !/^airzero-billing-push-[a-z0-9-]+@/.test(p.pushEmail) ||
      p.pushAudience !== `${endpoint}/v1/billing/notifications/play`) {
      throw new Error('billing_play_not_configured');
    }
    result.play = p;
  }
  if (env.AIRZERO_APPLE_MONTHLY_PRODUCT) {
    const a = { monthly: env.AIRZERO_APPLE_MONTHLY_PRODUCT, annual: env.AIRZERO_APPLE_ANNUAL_PRODUCT ?? '',
      group: env.AIRZERO_APPLE_SUBSCRIPTION_GROUP ?? '', appId: Number(env.AIRZERO_APPLE_STORE_APP_ID),
      key: env.AIRZERO_APPLE_IAP_PRIVATE_KEY ?? '', keyId: env.AIRZERO_APPLE_IAP_KEY_ID ?? '', issuer: env.AIRZERO_APPLE_IAP_ISSUER_ID ?? '' };
    if (![a.monthly, a.annual].every(id) || a.monthly === a.annual || !/^\d+$/.test(a.group) ||
      !Number.isSafeInteger(a.appId) || a.appId <= 0 || !a.key.includes('PRIVATE KEY') ||
      !/^[A-Z0-9]{10}$/.test(a.keyId) || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(a.issuer)) throw new Error('billing_apple_not_configured');
    try {
      const privateKey = createPrivateKey(a.key);
      if (privateKey.asymmetricKeyType !== 'ec' || privateKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1') throw new Error('invalid_key');
    } catch { throw new Error('billing_apple_not_configured'); }
    result.apple = a;
  }
  if (!result.play && !result.apple) throw new Error('billing_products_not_configured');
  return result;
}
export interface VerifiedSubscription {
  store: Store; reference: string; product: string; period: Period; binding: string;
  state: PaidState; validUntilMs: number; autoRenew: boolean; acknowledged: boolean;
  linkedReference?: string;
}
export interface StoreVerifier {
  resolve(store: Store, reference: string): Promise<string>;
  verify(store: Store, canonicalReference: string): Promise<VerifiedSubscription>;
  acknowledge(value: VerifiedSubscription): Promise<void>;
  notification(store: Store, body: unknown, authorization?: string): Promise<string | null>;
  worker(authorization?: string): Promise<void>;
}
export const permits = (v: Pick<VerifiedSubscription, 'state' | 'validUntilMs'>, now: number) =>
  ['active', 'canceled', 'grace'].includes(v.state) && Number.isSafeInteger(v.validUntilMs) && v.validUntilMs > now;

export function parsePlay(value: Record<string, any>, config: BillingConfig, environment: string): VerifiedSubscription {
  const p = config.play;
  const line = value.lineItems?.[0];
  if (!p || !Array.isArray(value.lineItems) || value.lineItems.length !== 1 || line?.productId !== p.product ||
      line.offerDetails?.offerId !== undefined ||
      !line.autoRenewingPlan || typeof line.autoRenewingPlan.autoRenewEnabled !== 'boolean' ||
      line.autoRenewingPlan.installmentDetails !== undefined || line.prepaidPlan !== undefined ||
      (value.testPurchase !== undefined) !== (environment === 'dev')) throw new ApiError(403, 'purchase_scope_denied');
  const plan = line.offerDetails?.basePlanId;
  const period = plan === p.monthly ? 'monthly' : plan === p.annual ? 'annual' : null;
  const states: Record<string, PaidState> = { SUBSCRIPTION_STATE_ACTIVE: 'active', SUBSCRIPTION_STATE_CANCELED: 'canceled',
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'grace', SUBSCRIPTION_STATE_ON_HOLD: 'hold', SUBSCRIPTION_STATE_PAUSED: 'paused',
    SUBSCRIPTION_STATE_EXPIRED: 'expired', SUBSCRIPTION_STATE_PENDING: 'pending', SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: 'expired' };
  const state = states[value.subscriptionState];
  const binding = value.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  const expiry = Date.parse(line.expiryTime ?? '');
  if (!period || !state || typeof binding !== 'string' || !/^[a-f0-9-]{36}$/i.test(binding) ||
      (!Number.isFinite(expiry) && state !== 'pending' && state !== 'expired')) throw new ApiError(403, 'purchase_scope_denied');
  return { store: 'play', reference: '', product: p.product, period, binding, state,
    validUntilMs: Number.isFinite(expiry) ? expiry : 0, autoRenew: line.autoRenewingPlan.autoRenewEnabled,
    acknowledged: value.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
    ...(typeof value.linkedPurchaseToken === 'string' ? { linkedReference: value.linkedPurchaseToken } : {}) };
}

export class OfficialStoreVerifier implements StoreVerifier {
  private readonly google = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
  private readonly oidc = new OAuth2Client();
  private appleClient?: AppStoreServerAPIClient;
  private appleProof?: SignedDataVerifier;
  constructor(private readonly runtime: RuntimeConfig, private readonly config: BillingConfig) {}
  private apple() {
    if (!this.config.apple) throw new ApiError(503, 'billing_setup_required');
    if (!this.appleClient) {
      const c = this.config.apple, env = this.runtime.environment === 'dev' ? Environment.SANDBOX : Environment.PRODUCTION;
      const root = readFileSync(new URL('../../certs/AppleRootCA-G3.cer', import.meta.url));
      if (createHash('sha256').update(root).digest('hex') !== '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179') throw new Error('apple_root_mismatch');
      this.appleClient = new AppStoreServerAPIClient(c.key, c.keyId, c.issuer, billingPackage, env);
      this.appleProof = new SignedDataVerifier([root], true, env, billingPackage, c.appId);
    }
    return { client: this.appleClient, proof: this.appleProof! };
  }
  async resolve(store: Store, reference: string): Promise<string> {
    if (store === 'play') {
      if (!/^[A-Za-z0-9._~+=:/-]{16,4096}$/.test(reference)) throw new ApiError(400, 'invalid_purchase');
      return reference;
    }
    if (!/^\d{1,30}$/.test(reference)) throw new ApiError(400, 'invalid_purchase');
    const a = this.apple(), info = await a.client.getTransactionInfo(reference);
    const tx = await a.proof.verifyAndDecodeTransaction(info.signedTransactionInfo ?? '');
    if (!tx.originalTransactionId) throw new ApiError(403, 'purchase_scope_denied');
    return tx.originalTransactionId;
  }
  async verify(store: Store, reference: string): Promise<VerifiedSubscription> {
    if (store === 'play') {
      if (!this.config.play) throw new ApiError(503, 'billing_setup_required');
      const client = await this.google.getClient();
      const response = await client.request<Record<string, any>>({ url:
        `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${billingPackage}/purchases/subscriptionsv2/tokens/${encodeURIComponent(reference)}`,
        timeout: 12000 });
      return { ...parsePlay(response.data, this.config, this.runtime.environment), reference };
    }
    const a = this.apple(), c = this.config.apple!;
    const result = await a.client.getAllSubscriptionStatuses(reference);
    const env = this.runtime.environment === 'dev' ? Environment.SANDBOX : Environment.PRODUCTION;
    if (result.bundleId !== billingPackage || result.environment !== env || result.appAppleId !== c.appId) throw new ApiError(403, 'purchase_scope_denied');
    const candidates: { value: VerifiedSubscription; date: number }[] = [];
    for (const group of result.data ?? []) for (const item of group.lastTransactions ?? []) {
      if (item.originalTransactionId !== reference) continue;
      const tx = await a.proof.verifyAndDecodeTransaction(item.signedTransactionInfo ?? '');
      const renewal = await a.proof.verifyAndDecodeRenewalInfo(item.signedRenewalInfo ?? '');
      const period = tx.productId === c.monthly ? 'monthly' : tx.productId === c.annual ? 'annual' : null;
      const state = ({ 1: 'active', 2: 'expired', 3: 'hold', 4: 'grace', 5: 'revoked' } as const)[item.status as 1|2|3|4|5];
      if (!period || !state || tx.originalTransactionId !== reference || renewal.originalTransactionId !== reference ||
          tx.bundleId !== billingPackage || tx.environment !== env || tx.subscriptionGroupIdentifier !== c.group ||
          tx.type !== 'Auto-Renewable Subscription' || tx.inAppOwnershipType !== 'PURCHASED' || tx.offerType !== undefined ||
          typeof tx.appAccountToken !== 'string') throw new ApiError(403, 'purchase_scope_denied');
      const expiry = state === 'grace' ? renewal.gracePeriodExpiresDate : tx.expiresDate;
      if (!Number.isSafeInteger(expiry)) throw new ApiError(403, 'purchase_scope_denied');
      candidates.push({ date: tx.purchaseDate ?? 0, value: { store, reference, product: tx.productId!, period,
        binding: tx.appAccountToken.toLowerCase(), state: tx.revocationDate ? 'revoked' : state,
        validUntilMs: expiry!, autoRenew: renewal.autoRenewStatus === 1, acknowledged: true } });
    }
    candidates.sort((a, b) => b.date - a.date);
    if (!candidates[0]) throw new ApiError(403, 'purchase_scope_denied');
    return candidates[0].value;
  }
  async acknowledge(v: VerifiedSubscription) {
    if (v.store !== 'play' || v.acknowledged || !permits(v, Date.now())) return;
    const client = await this.google.getClient();
    await client.request({ method: 'POST', timeout: 12000, url:
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${billingPackage}/purchases/subscriptions/${encodeURIComponent(v.product)}/tokens/${encodeURIComponent(v.reference)}:acknowledge`, data: {} });
  }
  private async checkOidc(authorization: string | undefined, email: string | undefined, audience: string | undefined) {
    if (!email || !audience || !authorization?.startsWith('Bearer ')) throw new ApiError(401, 'invalid_notification');
    try {
      const payload = (await this.oidc.verifyIdToken({ idToken: authorization.slice(7), audience })).getPayload();
      if (payload?.email !== email || payload.email_verified !== true ||
          !['accounts.google.com', 'https://accounts.google.com'].includes(payload.iss)) throw new Error('invalid_push');
    } catch { throw new ApiError(401, 'invalid_notification'); }
  }
  async worker(authorization?: string) {
    await this.checkOidc(authorization, this.config.workerEmail, this.config.workerAudience);
  }
  async notification(store: Store, body: any, authorization?: string): Promise<string | null> {
    if (store === 'play') {
      await this.checkOidc(authorization, this.config.play?.pushEmail, this.config.play?.pushAudience);
      const encoded = body?.message?.data;
      if (typeof encoded !== 'string' || encoded.length > 20000) throw new ApiError(400, 'invalid_notification');
      let data; try { data = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8')); } catch { throw new ApiError(400, 'invalid_notification'); }
      if (data.packageName !== billingPackage) throw new ApiError(403, 'purchase_scope_denied');
      const reference = data.subscriptionNotification?.purchaseToken ?? data.voidedPurchaseNotification?.purchaseToken;
      return typeof reference === 'string' ? reference : null;
    }
    if (typeof body?.signedPayload !== 'string' || body.signedPayload.length > 30000) throw new ApiError(400, 'invalid_notification');
    const a = this.apple(), decoded = await a.proof.verifyAndDecodeNotification(body.signedPayload);
    if (!decoded.data?.signedTransactionInfo) return null;
    const tx = await a.proof.verifyAndDecodeTransaction(decoded.data.signedTransactionInfo);
    return tx.originalTransactionId ?? null;
  }
}
