import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getAppCheck } from 'firebase-admin/app-check';
import { getFirestore } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { warn } from 'firebase-functions/logger';
import { createApi } from './api.js';
import { AccountRepository } from './repository.js';
import { FirebaseSessionVerifier, loadConfig } from './security.js';
import { EmailService } from './email.js';
import { defineSecret } from 'firebase-functions/params';
import { SocialService } from './social.js';
import { loadSocialConfig, OfficialSocialVerifier } from './social-proof.js';
import { AccountService } from './account.js';
import { BillingService } from './billing.js';
import { loadBillingConfig, OfficialStoreVerifier } from './billing-store.js';

// Validate scope BEFORE Admin SDK initialization. No credentials in app assets.
const config = loadConfig(process.env);
const app = initializeApp({ projectId: config.projectId });
const repository = new AccountRepository(getFirestore(app), config);
const verifier = new FirebaseSessionVerifier(getAuth(app), getAppCheck(app), config, Date.now,
  (uid, grant, time) => repository.resolveSocialGrant(uid, grant, time));
const email = new EmailService(config, getAuth(app), getFirestore(app), verifier, repository, process.env);
const mailSecret = defineSecret('AIRZERO_EMAIL_RATE_SECRET');
const socialSecret = defineSecret('AIRZERO_SOCIAL_RATE_SECRET');
const accountSecret = defineSecret('AIRZERO_ACCOUNT_RATE_SECRET');
const billingSeal = defineSecret('AIRZERO_BILLING_SEAL_KEY');
const appleIap = defineSecret('AIRZERO_APPLE_IAP_PRIVATE_KEY');
const socialConfig = loadSocialConfig(process.env);
const social = new SocialService(config, socialConfig, getAuth(app), getFirestore(app), repository, verifier,
  new OfficialSocialVerifier(socialConfig), process.env.AIRZERO_SOCIAL_RATE_SECRET);
const account = new AccountService(config, getAuth(app), getFirestore(app), repository, verifier, process.env);
let billingService: BillingService | undefined;
const getBilling = () => {
  if (!billingService) {
    const settings = loadBillingConfig(process.env);
    billingService = new BillingService(config, settings, getFirestore(app), repository, verifier,
      new OfficialStoreVerifier(config, settings));
  }
  return billingService;
};
const billing: Pick<BillingService, 'handle' | 'background'> = {
  handle: (...args) => getBilling().handle(...args), background: (...args) => getBilling().background(...args),
};
export const api = onRequest({ region: config.region, maxInstances: 3, minInstances: 0,
  ...(config.mode === 'cloud' ? { secrets: [mailSecret, socialSecret, accountSecret,
    ...(process.env.AIRZERO_BILLING_READY === 'true' ? [billingSeal] : []),
    ...(process.env.AIRZERO_BILLING_READY === 'true' && process.env.AIRZERO_APPLE_MONTHLY_PRODUCT ? [appleIap] : [])] } : {}),
  ...(config.serviceAccount ? { serviceAccount: config.serviceAccount } : {}),
  timeoutSeconds: 30, memory: '256MiB', cors: false },
  createApi(config, verifier, repository, (code, status) => warn('request_rejected', { code, status }), email, social, account, billing));
