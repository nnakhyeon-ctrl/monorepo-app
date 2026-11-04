// Offline public-value inventory only. No .env, process.env, secrets, console
// calls, deployment or permission changes. Runtime validation remains server-side.
import { readFileSync, lstatSync, realpathSync } from 'node:fs';
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { inspectLocalPublicSetup } from './check_auth_readiness.mjs';

const fields = ['AIRZERO_PROJECT_ID', 'AIRZERO_ENVIRONMENT', 'AIRZERO_ANDROID_PACKAGE', 'AIRZERO_IOS_BUNDLE',
  'AIRZERO_BILLING_READY', 'AIRZERO_PLAY_SUBSCRIPTION_ID', 'AIRZERO_PLAY_MONTHLY_PLAN', 'AIRZERO_PLAY_ANNUAL_PLAN',
  'AIRZERO_APPLE_MONTHLY_PRODUCT', 'AIRZERO_APPLE_ANNUAL_PRODUCT', 'AIRZERO_APPLE_SUBSCRIPTION_GROUP', 'AIRZERO_APPLE_STORE_APP_ID',
  'AIRZERO_TERMS_URL', 'AIRZERO_PRIVACY_URL', 'AIRZERO_SUPPORT_URL', 'AIRZERO_ACCOUNT_DELETION_URL'];
const products = fields.slice(5, 10);
const numeric = fields.slice(10, 12);
const urls = fields.slice(12);
const bundle = 'com.example.raikeopeu2026.dev';
function publicHttps(value) {
  try {
    const u = new URL(value);
    return u.protocol === 'https:' && !u.username && !u.password && !u.search && !u.hash &&
      (!u.port || u.port === '443') && !['localhost', '127.0.0.1', '[::1]'].includes(u.hostname) && !u.hostname.endsWith('.test');
  } catch { return false; }
}
export function evaluateBillingSetup(input) {
  const checks = [];
  const add = (id, status, code) => checks.push({ id, status, code });
  const schema = input && typeof input === 'object' && !Array.isArray(input) &&
    Object.keys(input).length === fields.length && fields.every(k => Object.hasOwn(input, k)) &&
    fields.every(k => k === 'AIRZERO_BILLING_READY' ? typeof input[k] === 'boolean' :
      typeof input[k] === 'string' && input[k].length <= 512);
  add('public_schema', schema ? 'PASS' : 'BLOCKED', schema ? 'public_fields_only' : 'missing_or_unexpected_fields');
  if (schema) {
    add('app_and_environment', input.AIRZERO_PROJECT_ID === 'airzero-strike-dev' && input.AIRZERO_ENVIRONMENT === 'dev' &&
      input.AIRZERO_ANDROID_PACKAGE === bundle && input.AIRZERO_IOS_BUNDLE === bundle ? 'PASS' : 'BLOCKED', 'existing_dev_identifiers_required');
    for (const key of [...products, ...numeric, ...urls]) {
      const value = input[key];
      add(key, !value ? 'PENDING' : (products.includes(key) ? /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(value) :
        numeric.includes(key) ? /^\d+$/.test(value) && Number.isSafeInteger(Number(value)) && Number(value) > 0 : publicHttps(value)) ? 'PASS' : 'BLOCKED',
      !value ? 'not_configured' : 'format_only_not_console_evidence');
    }
    for (const [name, a, b] of [['play_distinct_base_plans', 'AIRZERO_PLAY_MONTHLY_PLAN', 'AIRZERO_PLAY_ANNUAL_PLAN'],
      ['apple_distinct_products', 'AIRZERO_APPLE_MONTHLY_PRODUCT', 'AIRZERO_APPLE_ANNUAL_PRODUCT']]) {
      add(name, !input[a] || !input[b] ? 'PENDING' : input[a] !== input[b] ? 'PASS' : 'BLOCKED', 'distinct_monthly_and_annual_required');
    }
    add('purchase_activation', input.AIRZERO_BILLING_READY ? 'REVIEW' : 'PASS',
      input.AIRZERO_BILLING_READY ? 'flag_is_not_evidence_of_live_connection' : 'purchase_remains_disabled');
  }
  return { scope: 'LOCAL_PUBLIC_FORMAT_ONLY', localStatus: checks.some(c => c.status === 'BLOCKED') ? 'BLOCKED' :
    checks.some(c => ['PENDING', 'REVIEW'].includes(c.status)) ? 'PENDING' : 'REVIEW',
    liveVerification: 'NOT_RUN', checks,
    notChecked: ['store_registration_and_prices', 'deployed_auth_billing_app_check_iam', 'server_secrets_and_notifications',
      'public_web_deletion_and_policies', 'play_license_test', 'apple_membership_sandbox_ios', 'physical_devices', 'refund_and_account_recovery_policy'] };
}
function readPublic(root, parts) {
  try {
    const base = realpathSync(root);
    let current = base;
    for (const part of parts) { current = join(current, part); if (lstatSync(current).isSymbolicLink()) return null; }
    const stat = lstatSync(current);
    if (!stat.isFile() || stat.size > 16384 || !realpathSync(current).startsWith(base + sep)) return null;
    return JSON.parse(readFileSync(current, 'utf8'));
  } catch { return null; }
}
export function inspectBillingSetup(root) {
  const local = ['config', '.local-public', 'billing.dev.public.json'];
  let exists = true;
  try { lstatSync(join(root, ...local)); } catch (e) { exists = e.code !== 'ENOENT'; }
  const report = evaluateBillingSetup(readPublic(root, exists ? local : ['config', 'billing.public.example.json']));
  const auth = inspectLocalPublicSetup(root);
  return { ...report, source: exists ? 'LOCAL_PUBLIC_INVENTORY_NOT_RUNTIME' : 'EXAMPLE_ONLY_NOT_RUNTIME',
    authLocalStatus: auth.localStatus, authLiveVerification: auth.liveVerification };
}
if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  if (process.argv.length !== 2) { console.error('No paths, secrets or arguments accepted.'); process.exitCode = 1; }
  else {
    const report = inspectBillingSetup(resolve(dirname(fileURLToPath(import.meta.url)), '..'));
    console.log(JSON.stringify(report, null, 2));
    // Distinguish missing preparation from invalid input; neither may gate a sale.
    process.exitCode = report.localStatus === 'BLOCKED' ? 1 : report.localStatus === 'PENDING' ? 2 : 0;
  }
}
