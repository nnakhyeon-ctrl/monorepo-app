import { createHash } from 'node:crypto';
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { ApiError, type ProviderIdentity } from './security.js';

export type SocialProvider = 'google' | 'kakao' | 'apple';
export type SocialPlatform = 'play' | 'app-store';
export const socialId = { google: 'google.com', kakao: 'kakao', apple: 'apple.com' } as const;
export interface SocialConfig {
  google?: { audience: string; androidClients: string[]; iosClients: string[] };
  kakao?: { nativeKey: string; appId: number };
  apple?: { bundleId: string };
}
export function loadSocialConfig(env: NodeJS.ProcessEnv): SocialConfig {
  const result: SocialConfig = {};
  const clients = (s = '') => s.split(',').filter(Boolean);
  const client = (s: string) => /^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$/.test(s);
  if (env.AIRZERO_GOOGLE_READY === 'true') {
    const audience = env.AIRZERO_GOOGLE_WEB_CLIENT_ID ?? '';
    const androidClients = clients(env.AIRZERO_GOOGLE_ANDROID_CLIENT_IDS);
    const iosClients = clients(env.AIRZERO_GOOGLE_IOS_CLIENT_IDS);
    if (!client(audience) || androidClients.length + iosClients.length === 0 ||
        [...androidClients, ...iosClients].some((c) => !client(c))) throw new Error('invalid_google_configuration');
    result.google = { audience, androidClients, iosClients };
  }
  if (env.AIRZERO_KAKAO_READY === 'true') {
    const nativeKey = env.AIRZERO_KAKAO_NATIVE_KEY ?? '', appId = Number(env.AIRZERO_KAKAO_APP_ID);
    if (!/^[a-f0-9]{32}$/.test(nativeKey) || !Number.isSafeInteger(appId) || appId <= 0) throw new Error('invalid_kakao_configuration');
    result.kakao = { nativeKey, appId };
  }
  if (env.AIRZERO_APPLE_READY === 'true') {
    const bundleId = env.AIRZERO_APPLE_BUNDLE_ID ?? '';
    if (!/^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+){2,}$/.test(bundleId)) throw new Error('invalid_apple_configuration');
    result.apple = { bundleId };
  }
  return result;
}
export interface SocialChallenge {
  provider: SocialProvider; platform: SocialPlatform; nonceDigest: string; createdAtMs: number;
}
export interface SocialProofVerifier {
  verify(proof: Record<string, unknown>, challenge: SocialChallenge): Promise<ProviderIdentity>;
}
const issuers = { google: ['https://accounts.google.com', 'accounts.google.com'],
  kakao: ['https://kauth.kakao.com'], apple: ['https://appleid.apple.com'] };
const keyUrls = { google: 'https://www.googleapis.com/oauth2/v3/certs',
  kakao: 'https://kauth.kakao.com/.well-known/jwks.json', apple: 'https://appleid.apple.com/auth/keys' };
export const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

/** Only fixed issuer JWKS URLs are used. Test key injection exists in test code,
 * never as an environment/configuration route in the deployed handler. */
export class OfficialSocialVerifier implements SocialProofVerifier {
  private readonly keys: Record<SocialProvider, JWTVerifyGetKey>;
  constructor(private readonly config: SocialConfig,
      keys?: Record<SocialProvider, JWTVerifyGetKey>, private readonly now = Date.now,
      private readonly request: typeof fetch = fetch) {
    const remote = (provider: SocialProvider) => createRemoteJWKSet(new URL(keyUrls[provider]),
      { timeoutDuration: 5000, cooldownDuration: 30000, cacheMaxAge: 600000 });
    this.keys = keys ?? { google: remote('google'), kakao: remote('kakao'), apple: remote('apple') };
  }
  async verify(proof: Record<string, unknown>, challenge: SocialChallenge): Promise<ProviderIdentity> {
    const provider = challenge.provider;
    if (proof.kind !== `${provider}-id-token` || typeof proof.idToken !== 'string' || proof.idToken.length > 8192 ||
        Object.keys(proof).some((k) => !['kind', 'idToken', ...(provider === 'kakao' ? ['accessToken'] : [])].includes(k))) {
      throw new ApiError(401, 'invalid_provider_proof');
    }
    const audience = provider === 'google' ? this.config.google?.audience :
      provider === 'kakao' ? this.config.kakao?.nativeKey : this.config.apple?.bundleId;
    if (!audience) throw new ApiError(503, 'social_setup_required');
    try {
      const { payload } = await jwtVerify(proof.idToken, this.keys[provider], {
        algorithms: ['RS256'], issuer: issuers[provider], audience,
        requiredClaims: ['sub', 'iss', 'aud', 'exp', 'iat', 'nonce'],
        maxTokenAge: '5m', clockTolerance: 5, currentDate: new Date(this.now()),
      });
      if (typeof payload.sub !== 'string' || !/^[A-Za-z0-9._-]{1,256}$/.test(payload.sub) ||
          !Number.isInteger(payload.iat) || payload.iat! * 1000 < challenge.createdAtMs - 10000 ||
          typeof payload.nonce !== 'string' ||
          (provider === 'apple' ? payload.nonce : sha256(payload.nonce)) !== challenge.nonceDigest) {
        throw new Error('invalid_claims');
      }
      if (provider === 'google') {
        const allowed = challenge.platform === 'play' ? this.config.google!.androidClients : this.config.google!.iosClients;
        if (!allowed.length || (payload.azp !== undefined &&
            (typeof payload.azp !== 'string' || ![audience, ...allowed].includes(payload.azp))) ||
            (Array.isArray(payload.aud) && payload.azp === undefined)) throw new Error('invalid_authorized_party');
      }
      if (provider === 'kakao') {
        // A Kakao access token is opaque. Never decode it as a JWT.
        if (typeof proof.accessToken !== 'string' || proof.accessToken.length > 4096 ||
            !/^[A-Za-z0-9._~+\/-]+=*$/.test(proof.accessToken)) throw new Error('invalid_access_token');
        const response = await this.request('https://kapi.kakao.com/v1/user/access_token_info', {
          headers: { Authorization: `Bearer ${proof.accessToken}` }, redirect: 'error', signal: AbortSignal.timeout(8000),
        });
        if (!response.ok) throw new Error('invalid_access_token');
        const reader = response.body?.getReader();
        if (!reader) throw new Error('invalid_response');
        const decoder = new TextDecoder();
        let raw = '', size = 0;
        while (true) {
          const part = await reader.read();
          if (part.done) break;
          size += part.value.byteLength;
          if (size > 8192) { await reader.cancel(); throw new Error('invalid_response'); }
          raw += decoder.decode(part.value, { stream: true });
        }
        raw += decoder.decode();
        const info = JSON.parse(raw) as Record<string, unknown>;
        if (info.app_id !== this.config.kakao!.appId || !Number.isSafeInteger(info.id) ||
            String(info.id) !== payload.sub || typeof info.expires_in !== 'number' || info.expires_in <= 0) throw new Error('invalid_access_token');
      }
      return { provider: socialId[provider], subject: payload.sub };
    } catch (_) {
      throw new ApiError(401, 'invalid_provider_proof');
    }
  }
}
