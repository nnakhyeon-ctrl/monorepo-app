// Synthetic signing keys exist only in tests. No deployed configuration accepts them.
import { generateKeyPair, exportJWK, createLocalJWKSet, SignJWT } from 'jose';
import { OfficialSocialVerifier, sha256, type SocialConfig, type SocialProvider } from '../src/social-proof.js';
export const config: SocialConfig = {
  google: { audience: 'fictional-web.apps.googleusercontent.com',
    androidClients: ['fictional-android.apps.googleusercontent.com'], iosClients: ['fictional-ios.apps.googleusercontent.com'] },
  kakao: { nativeKey: 'a'.repeat(32), appId: 12345 }, apple: { bundleId: 'com.example.raikeopeu2026.dev' },
};
export async function signingFixture(now: () => number = Date.now) {
  const pair = await generateKeyPair('RS256');
  const jwk = { ...await exportJWK(pair.publicKey), kid: 'synthetic-key', alg: 'RS256', use: 'sig' };
  const resolve = createLocalJWKSet({ keys: [jwk] });
  const request: typeof fetch = async () => Response.json({ app_id: 12345, id: 123456, expires_in: 300 });
  const keys = { google: resolve, kakao: resolve, apple: resolve };
  const token = async (provider: SocialProvider, nonce: string, overrides: Record<string, unknown> = {}) => {
    const aud = provider === 'google' ? config.google!.audience : provider === 'kakao' ? config.kakao!.nativeKey : config.apple!.bundleId;
    const iss = provider === 'google' ? 'https://accounts.google.com' : provider === 'kakao' ? 'https://kauth.kakao.com' : 'https://appleid.apple.com';
    return new SignJWT({ nonce: provider === 'apple' ? sha256(nonce) : nonce, ...overrides })
      .setProtectedHeader({ alg: 'RS256', kid: 'synthetic-key' })
      .setIssuer(typeof overrides.iss === 'string' ? overrides.iss : iss)
      .setAudience(typeof overrides.aud === 'string' ? overrides.aud : aud)
      .setSubject(typeof overrides.sub === 'string' ? overrides.sub : provider === 'kakao' ? '123456' : 'fictional_subject')
      .setIssuedAt(typeof overrides.iat === 'number' ? overrides.iat : Math.floor(now() / 1000))
      .setExpirationTime(typeof overrides.exp === 'number' ? overrides.exp : Math.floor(now() / 1000) + 300)
      .sign(pair.privateKey);
  };
  return { keys, token, verifier: new OfficialSocialVerifier(config, keys, now, request) };
}
