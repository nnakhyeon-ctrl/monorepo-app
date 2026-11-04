import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, basename, sep } from 'node:path';
import { evaluateSetup, inspectLocalPublicSetup } from './check_auth_readiness.mjs';

const fixture = () => {
  const web = '111-web.apps.googleusercontent.com', iosClient = '111-ios.apps.googleusercontent.com';
  const common = { AIRZERO_FIREBASE_PROJECT: 'airzero-strike-dev', AIRZERO_FIREBASE_API_KEY: `AIza${'x'.repeat(35)}`,
    AIRZERO_FIREBASE_SENDER_ID: '111', AIRZERO_ENVIRONMENT: 'dev', AIRZERO_REGION: 'asia-northeast3',
    AIRZERO_GOOGLE_WEB_CLIENT_ID: web, AIRZERO_GOOGLE_IOS_CLIENT_ID: '',
    AIRZERO_KAKAO_NATIVE_KEY: 'a'.repeat(32), AIRZERO_APPLE_LOGIN: false };
  const android = { ...common, AIRZERO_FIREBASE_APP_ID: '1:111:android:abc' };
  const ios = { ...common, AIRZERO_FIREBASE_APP_ID: '1:111:ios:def', AIRZERO_GOOGLE_IOS_CLIENT_ID: iosClient };
  const server = { AIRZERO_PROJECT_ID: 'airzero-strike-dev', AIRZERO_ENVIRONMENT: 'dev', AIRZERO_REGION: common.AIRZERO_REGION,
    AIRZERO_FIREBASE_APP_IDS: `${android.AIRZERO_FIREBASE_APP_ID},${ios.AIRZERO_FIREBASE_APP_ID}`,
    AIRZERO_GOOGLE_READY: false, AIRZERO_GOOGLE_WEB_CLIENT_ID: web,
    AIRZERO_GOOGLE_ANDROID_CLIENT_IDS: '111-android.apps.googleusercontent.com', AIRZERO_GOOGLE_IOS_CLIENT_IDS: iosClient,
    AIRZERO_KAKAO_READY: false, AIRZERO_KAKAO_NATIVE_KEY: common.AIRZERO_KAKAO_NATIVE_KEY, AIRZERO_KAKAO_APP_ID: '1614509',
    AIRZERO_APPLE_READY: false, AIRZERO_APPLE_BUNDLE_ID: 'com.example.raikeopeu2026.dev' };
  return { android, ios, server, callbacks: { AIRZERO_KAKAO_SCHEME: `kakao${common.AIRZERO_KAKAO_NATIVE_KEY}`,
    AIRZERO_GOOGLE_REVERSED_CLIENT_ID: iosClient.split('.').reverse().join('.') } };
};
test('matching public dev files pass locally and never assert a live login', () => {
  const f = fixture(), result = evaluateSetup(f);
  assert.equal(result.localStatus, 'PASS');
  assert.equal(result.liveVerification, 'NOT_RUN');
  const output = JSON.stringify(result);
  for (const value of [f.android.AIRZERO_FIREBASE_API_KEY, f.android.AIRZERO_KAKAO_NATIVE_KEY, f.server.AIRZERO_GOOGLE_WEB_CLIENT_ID]) {
    assert.equal(output.includes(value), false);
  }
});
test('other app/environment and foreign App Check app IDs block readiness', () => {
  for (const mutate of [f => f.server.AIRZERO_PROJECT_ID = 'other-app-dev',
    f => f.ios.AIRZERO_ENVIRONMENT = 'prod', f => f.server.AIRZERO_FIREBASE_APP_IDS = '1:222:android:abc,1:222:ios:def']) {
    const f = fixture(); mutate(f); assert.equal(evaluateSetup(f).localStatus, 'BLOCKED');
  }
});
test('mismatched OAuth, Kakao and native callbacks block readiness', () => {
  for (const mutate of [f => f.server.AIRZERO_GOOGLE_WEB_CLIENT_ID = '222-other.apps.googleusercontent.com',
    f => f.server.AIRZERO_KAKAO_NATIVE_KEY = 'b'.repeat(32), f => f.callbacks.AIRZERO_GOOGLE_REVERSED_CLIENT_ID = 'wrong']) {
    const f = fixture(); mutate(f); assert.equal(evaluateSetup(f).localStatus, 'BLOCKED');
  }
});
test('unexpected secret-like fields and malformed values are rejected without echoing contents', () => {
  const f = fixture(), marker = 'DO_NOT_LOG_PRIVATE_VALUE';
  f.android.CLIENT_SECRET = marker;
  const report = evaluateSetup(f);
  assert.equal(report.localStatus, 'BLOCKED');
  assert.equal(JSON.stringify(report).includes(marker), false);
  const invalid = fixture(); invalid.ios.AIRZERO_FIREBASE_SENDER_ID = '.*';
  assert.equal(evaluateSetup(invalid).localStatus, 'BLOCKED');
  const nested = fixture();
  nested.server.AIRZERO_KAKAO_APP_ID = { toString: marker };
  nested.ios.AIRZERO_KAKAO_NATIVE_KEY = { toString: marker };
  assert.equal(evaluateSetup(nested).localStatus, 'BLOCKED');
  assert.equal(JSON.stringify(evaluateSetup(nested)).includes(marker), false);
});
test('READY flags require review and cannot turn a local result into live verification', () => {
  const f = fixture(); f.server.AIRZERO_GOOGLE_READY = true;
  assert.equal(evaluateSetup(f).localStatus, 'REVIEW');
  assert.equal(evaluateSetup(f).liveVerification, 'NOT_RUN');
});
test('fixed file loader rejects broken JSON and symlinked public directories without reading targets', () => {
  const root = mkdtempSync(join(tmpdir(), 'airzero_public_readiness_'));
  assert.equal(dirname(resolve(root)), resolve(tmpdir()));
  assert.equal(basename(root).startsWith('airzero_public_readiness_'), true);
  const removeFixturePath = (path) => {
    const target = resolve(path), base = resolve(root);
    assert.equal(target === base || target.startsWith(base + sep), true);
    rmSync(target, { recursive: true, force: true });
  };
  try {
    mkdirSync(join(root, 'config', '.local-public'), { recursive: true });
    writeFileSync(join(root, 'config', '.local-public', 'android.dev.public.json'), '{"PRIVATE_MARKER":');
    const output = JSON.stringify(inspectLocalPublicSetup(root));
    assert.equal(output.includes('PRIVATE_MARKER'), false);
    assert.equal(inspectLocalPublicSetup(root).localStatus, 'BLOCKED');
    removeFixturePath(join(root, 'config', '.local-public'));
    const target = join(root, 'do-not-read'); mkdirSync(target);
    writeFileSync(join(target, 'android.dev.public.json'), JSON.stringify(fixture().android));
    symlinkSync(target, join(root, 'config', '.local-public'), process.platform === 'win32' ? 'junction' : 'dir');
    const result = inspectLocalPublicSetup(root);
    assert.equal(result.checks.find(c => c.id === 'android_public_schema').status, 'BLOCKED');
  } finally { removeFixturePath(root); }
});
