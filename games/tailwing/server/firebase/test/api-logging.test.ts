import test from 'node:test';
import assert from 'node:assert/strict';
import type { Request, Response } from 'firebase-functions/v2/https';
import { createApi } from '../src/api.js';
import { loadConfig, type SessionVerifier } from '../src/security.js';
import type { AccountRepository } from '../src/repository.js';

test('rejected API requests never echo credential/body/error details into response or application log', async () => {
  const marker = 'FICTIONAL_DO_NOT_ECHO_CREDENTIAL';
  const config = loadConfig({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-airzero-strike',
    FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9299', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8280' });
  const logs: unknown[] = [], replies: unknown[] = [];
  const verifier: SessionVerifier = { async verify() { throw new Error(marker); } };
  const api = createApi({ ...config, mode: 'cloud' }, verifier, {} as AccountRepository,
    (code, status) => logs.push({ code, status }));
  const request = { protocol: 'https', method: 'GET', path: '/v1/me/progress', query: {},
    rawBody: Buffer.alloc(0), headers: { authorization: `Bearer ${'f'.repeat(40)}` },
    body: { password: marker, reference: marker }, get: () => marker };
  const response = { set() { return this; }, status(status: number) { replies.push(status); return this; },
    json(value: unknown) { replies.push(value); return this; } };
  for (const req of [{ ...request, protocol: 'http' }, request, { ...request, query: { token: marker } }]) {
    await api(req as unknown as Request, response as unknown as Response);
  }
  assert.deepEqual(logs, [{ code: 'https_required', status: 400 },
    { code: 'service_unavailable', status: 503 }, { code: 'invalid_input', status: 400 }]);
  const output = JSON.stringify({ logs, replies });
  assert.equal(output.includes(marker), false);
  assert.equal(output.includes(request.headers.authorization), false);
  assert.equal(output.includes('stack'), false);
});
