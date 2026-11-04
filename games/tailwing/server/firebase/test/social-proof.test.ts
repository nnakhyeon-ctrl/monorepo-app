import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SignJWT } from 'jose';
import { ApiError } from '../src/security.js';
import { loadSocialConfig, OfficialSocialVerifier, sha256, type SocialProvider } from '../src/social-proof.js';
import { config, signingFixture } from './social-fixtures.js';

const now = 1800000000000;
const f = await signingFixture(() => now);
const nonce = 'synthetic_nonce_' + 'x'.repeat(30);
const challenge = (provider: SocialProvider) => ({ provider, platform: 'play' as const,
  nonceDigest: sha256(nonce), createdAtMs: now });
const proof = async (provider: SocialProvider, overrides = {}) => ({ kind: `${provider}-id-token`,
  idToken: await f.token(provider, nonce, overrides), ...(provider === 'kakao' ? { accessToken: 'opaque-synthetic-access' } : {}) });

test('provider configuration is disabled by default and rejects incomplete enabled settings', () => {
  assert.deepEqual(loadSocialConfig({}), {});
  for (const provider of ['GOOGLE', 'KAKAO', 'APPLE']) assert.throws(() => loadSocialConfig({ [`AIRZERO_${provider}_READY`]: 'true' }));
});
test('Google, Kakao and Apple signed identities work without an email or profile', async () => {
  for (const provider of ['google', 'kakao', 'apple'] as const) {
    const result = await f.verifier.verify(await proof(provider), challenge(provider));
    assert.equal(result.provider, provider === 'kakao' ? 'kakao' : `${provider}.com`);
    assert.deepEqual(Object.keys(result).sort(), ['provider', 'subject']);
  }
});
test('issuer, audience, authorized party, expiry, nonce, age and signature are enforced', async () => {
  for (const overrides of [{ iss: 'https://other.invalid' }, { aud: 'other-app' },
    { azp: 'other-client.apps.googleusercontent.com' }, { exp: now / 1000 - 60 },
    { nonce: 'other_nonce' }, { iat: now / 1000 - 400 }, { iat: now / 1000 + 60 }]) {
    await assert.rejects(f.verifier.verify(await proof('google', overrides), challenge('google')), ApiError);
  }
  const other = await signingFixture(() => now);
  await assert.rejects(f.verifier.verify({ kind: 'google-id-token', idToken: await other.token('google', nonce) }, challenge('google')), ApiError);
  const hs = await new SignJWT({ nonce }).setProtectedHeader({ alg: 'HS256' }).sign(new Uint8Array(32));
  await assert.rejects(f.verifier.verify({ kind: 'google-id-token', idToken: hs }, challenge('google')), ApiError);
  await assert.rejects(f.verifier.verify(await proof('apple', { nonce }), challenge('apple')), ApiError);
});
test('token kinds and Kakao opaque access-token app, subject, lifetime and network response are checked', async () => {
  assert.equal((await f.verifier.verify({ ...await proof('kakao'), accessToken: 'opaque+/synthetic==' }, challenge('kakao'))).subject, '123456');
  await assert.rejects(f.verifier.verify(await proof('google'), challenge('kakao')), ApiError);
  await assert.rejects(f.verifier.verify({ ...await proof('google'), accessToken: 'unexpected' }, challenge('google')), ApiError);
  await assert.rejects(f.verifier.verify({ ...await proof('kakao'), accessToken: undefined }, challenge('kakao')), ApiError);
  for (const info of [{ app_id: 999, id: 123456, expires_in: 300 },
    { app_id: 12345, id: 999, expires_in: 300 }, { app_id: 12345, id: 123456, expires_in: 0 }]) {
    const request: typeof fetch = async (url, init) => {
      assert.equal(String(url), 'https://kapi.kakao.com/v1/user/access_token_info');
      assert.equal(init?.redirect, 'error');
      return Response.json(info);
    };
    await assert.rejects(new OfficialSocialVerifier(config, f.keys, () => now, request).verify(await proof('kakao'), challenge('kakao')), ApiError);
  }
  const request: typeof fetch = async () => { throw new Error('synthetic network failure'); };
  await assert.rejects(new OfficialSocialVerifier(config, f.keys, () => now, request).verify(await proof('kakao'), challenge('kakao')), ApiError);
  const oversized: typeof fetch = async () => new Response(' '.repeat(9000));
  await assert.rejects(new OfficialSocialVerifier(config, f.keys, () => now, oversized).verify(await proof('kakao'), challenge('kakao')), ApiError);
});
