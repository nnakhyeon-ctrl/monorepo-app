// Read-only, offline checks of this app's explicitly named PUBLIC dev files.
// Never load .env, credentials, CLI accounts, device data or arbitrary paths.
import { readFileSync, lstatSync, realpathSync } from 'node:fs';
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const mobileKeys = ['AIRZERO_FIREBASE_PROJECT', 'AIRZERO_FIREBASE_API_KEY',
  'AIRZERO_FIREBASE_APP_ID', 'AIRZERO_FIREBASE_SENDER_ID', 'AIRZERO_ENVIRONMENT',
  'AIRZERO_REGION', 'AIRZERO_GOOGLE_WEB_CLIENT_ID', 'AIRZERO_GOOGLE_IOS_CLIENT_ID',
  'AIRZERO_KAKAO_NATIVE_KEY', 'AIRZERO_APPLE_LOGIN'];
const serverKeys = ['AIRZERO_PROJECT_ID', 'AIRZERO_ENVIRONMENT', 'AIRZERO_REGION',
  'AIRZERO_FIREBASE_APP_IDS', 'AIRZERO_GOOGLE_READY', 'AIRZERO_GOOGLE_WEB_CLIENT_ID',
  'AIRZERO_GOOGLE_ANDROID_CLIENT_IDS', 'AIRZERO_GOOGLE_IOS_CLIENT_IDS',
  'AIRZERO_KAKAO_READY', 'AIRZERO_KAKAO_NATIVE_KEY', 'AIRZERO_KAKAO_APP_ID',
  'AIRZERO_APPLE_READY', 'AIRZERO_APPLE_BUNDLE_ID'];
const callbackKeys = ['AIRZERO_KAKAO_SCHEME', 'AIRZERO_GOOGLE_REVERSED_CLIENT_ID'];
const flag = (value) => [true, false, 'true', 'false'].includes(value);
const enabled = (value) => value === true || value === 'true';
const text = (value) => typeof value === 'string' && value.length <= 512;
const client = (value) => text(value) && /^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$/.test(value);
const list = (value) => text(value) ? value.split(',').filter(Boolean) : [];
const shape = (obj, keys) => obj !== null && typeof obj === 'object' && !Array.isArray(obj) &&
  Object.keys(obj).length === keys.length && keys.every((key) => Object.hasOwn(obj, key));

export function evaluateSetup({ android, ios, server, callbacks }) {
  const checks = [];
  const add = (id, pass, code = 'local_values_match') => checks.push({ id,
    status: pass ? 'PASS' : 'BLOCKED', code: pass ? 'local_values_match' : code });
  const a = shape(android, mobileKeys), i = shape(ios, mobileKeys);
  const s = shape(server, serverKeys), c = shape(callbacks, callbackKeys);
  add('android_public_schema', a, 'missing_invalid_or_unexpected_fields');
  add('ios_public_schema', i, 'missing_invalid_or_unexpected_fields');
  add('server_public_schema', s, 'missing_invalid_or_unexpected_fields');
  add('ios_callback_schema', c, 'missing_invalid_or_unexpected_fields');
  if (a && i && s) {
    const p = 'airzero-strike-dev';
    add('project_and_environment', android.AIRZERO_FIREBASE_PROJECT === p &&
      ios.AIRZERO_FIREBASE_PROJECT === p && server.AIRZERO_PROJECT_ID === p &&
      [android, ios, server].every((o) => o.AIRZERO_ENVIRONMENT === 'dev'), 'wrong_app_or_environment');
    add('planned_endpoint_region', [android, ios, server].every((o) => o.AIRZERO_REGION === 'asia-northeast3'),
      'endpoint_region_mismatch_not_database_location');
    for (const [platform, obj] of [['android', android], ['ios', ios]]) {
      const sender = obj.AIRZERO_FIREBASE_SENDER_ID;
      add(`${platform}_firebase_format`, text(sender) && /^\d+$/.test(sender) &&
        text(obj.AIRZERO_FIREBASE_APP_ID) && new RegExp(`^1:${sender}:${platform}:[a-f0-9]+$`).test(obj.AIRZERO_FIREBASE_APP_ID) &&
        text(obj.AIRZERO_FIREBASE_API_KEY) && /^AIza[A-Za-z0-9_-]{35}$/.test(obj.AIRZERO_FIREBASE_API_KEY), 'public_firebase_format_mismatch');
    }
    const ids = list(server.AIRZERO_FIREBASE_APP_IDS);
    add('server_mobile_allowlist', ids.length === 2 && new Set(ids).size === 2 &&
      ids.includes(android.AIRZERO_FIREBASE_APP_ID) && ids.includes(ios.AIRZERO_FIREBASE_APP_ID) &&
      android.AIRZERO_FIREBASE_SENDER_ID === ios.AIRZERO_FIREBASE_SENDER_ID, 'mobile_app_allowlist_mismatch');
    add('google_public_clients', client(android.AIRZERO_GOOGLE_WEB_CLIENT_ID) &&
      client(ios.AIRZERO_GOOGLE_IOS_CLIENT_ID) &&
      android.AIRZERO_GOOGLE_WEB_CLIENT_ID === ios.AIRZERO_GOOGLE_WEB_CLIENT_ID &&
      ios.AIRZERO_GOOGLE_WEB_CLIENT_ID === server.AIRZERO_GOOGLE_WEB_CLIENT_ID &&
      list(server.AIRZERO_GOOGLE_ANDROID_CLIENT_IDS).length > 0 &&
      list(server.AIRZERO_GOOGLE_ANDROID_CLIENT_IDS).every(client) &&
      list(server.AIRZERO_GOOGLE_IOS_CLIENT_IDS).every(client) &&
      list(server.AIRZERO_GOOGLE_IOS_CLIENT_IDS).includes(ios.AIRZERO_GOOGLE_IOS_CLIENT_ID), 'oauth_client_mismatch');
    add('kakao_public_app', text(android.AIRZERO_KAKAO_NATIVE_KEY) &&
      /^[a-f0-9]{32}$/.test(android.AIRZERO_KAKAO_NATIVE_KEY) &&
      android.AIRZERO_KAKAO_NATIVE_KEY === ios.AIRZERO_KAKAO_NATIVE_KEY &&
      ios.AIRZERO_KAKAO_NATIVE_KEY === server.AIRZERO_KAKAO_NATIVE_KEY &&
      (server.AIRZERO_KAKAO_APP_ID === '1614509' || server.AIRZERO_KAKAO_APP_ID === 1614509), 'kakao_app_mismatch');
    add('apple_bundle', server.AIRZERO_APPLE_BUNDLE_ID === 'com.example.raikeopeu2026.dev', 'bundle_id_mismatch');
    const flags = [android.AIRZERO_APPLE_LOGIN, ios.AIRZERO_APPLE_LOGIN,
      server.AIRZERO_GOOGLE_READY, server.AIRZERO_KAKAO_READY, server.AIRZERO_APPLE_READY];
    add('readiness_flag_types', flags.every(flag), 'invalid_readiness_flag');
    checks.push({ id: 'readiness_flags', status: flags.some(enabled) ? 'REVIEW' : 'PASS',
      code: flags.some(enabled) ? 'flags_are_not_evidence_of_live_connection' : 'providers_remain_disabled' });
    if (c) {
      add('ios_kakao_callback', text(ios.AIRZERO_KAKAO_NATIVE_KEY) &&
        callbacks.AIRZERO_KAKAO_SCHEME === `kakao${ios.AIRZERO_KAKAO_NATIVE_KEY}`, 'ios_kakao_callback_mismatch');
      add('ios_google_callback', client(ios.AIRZERO_GOOGLE_IOS_CLIENT_ID) &&
        callbacks.AIRZERO_GOOGLE_REVERSED_CLIENT_ID === ios.AIRZERO_GOOGLE_IOS_CLIENT_ID.split('.').reverse().join('.'),
      'ios_google_callback_mismatch');
    }
  }
  return { scope: 'LOCAL_PUBLIC_FILES_ONLY',
    localStatus: checks.some((check) => check.status === 'BLOCKED') ? 'BLOCKED' :
      checks.some((check) => check.status === 'REVIEW') ? 'REVIEW' : 'PASS',
    liveVerification: 'NOT_RUN', checks,
    notChecked: ['console_state_and_billing', 'deployed_server_and_database_region',
      'provider_login_and_signatures', 'iam_secrets_and_app_check',
      'external_web_auth_and_public_url', 'apple_membership_and_revocation', 'ios_and_physical_devices'] };
}

function readBoundedPublic(root, parts) {
  try {
    const base = realpathSync(root);
    let current = base;
    for (const part of parts) {
      current = join(current, part);
      if (lstatSync(current).isSymbolicLink()) return null;
    }
    const info = lstatSync(current);
    if (!info.isFile() || info.size > 16384 || !realpathSync(current).startsWith(base + sep)) return null;
    return readFileSync(current, 'utf8');
  } catch { return null; } // Never print parser/OS errors or configuration excerpts.
}
function readPublicJson(root, name) {
  try {
    const value = readBoundedPublic(root, ['config', '.local-public', name]);
    return value === null ? null : JSON.parse(value);
  } catch { return null; }
}
export function inspectLocalPublicSetup(root) {
  const source = readBoundedPublic(root, ['ios', 'Flutter', 'AuthPublic.local.xcconfig']);
  let callbacks = null;
  if (source !== null) {
    callbacks = {};
    for (const line of source.split(/\r?\n/)) {
      if (!line.trim() || line.trim().startsWith('//')) continue;
      const match = /^\s*([A-Z_]+)\s*=\s*([^\r\n]+?)\s*$/.exec(line);
      if (!match || !callbackKeys.includes(match[1]) || Object.hasOwn(callbacks, match[1])) { callbacks = null; break; }
      callbacks[match[1]] = match[2];
    }
  }
  return evaluateSetup({ android: readPublicJson(root, 'android.dev.public.json'),
    ios: readPublicJson(root, 'ios.dev.public.json'), server: readPublicJson(root, 'server.dev.public.json'), callbacks });
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  if (process.argv.length !== 2) {
    console.error('This read-only check accepts no paths, tokens or arguments.');
    process.exitCode = 1;
  } else {
    const report = inspectLocalPublicSetup(resolve(dirname(fileURLToPath(import.meta.url)), '..'));
    console.log(JSON.stringify(report, null, 2));
    process.exitCode = report.localStatus === 'PASS' ? 0 : 1;
  }
}
