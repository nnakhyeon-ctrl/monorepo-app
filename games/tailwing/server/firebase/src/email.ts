import { createHash, createHmac, randomInt } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { setTimeout as pause } from 'node:timers/promises';
import type { Auth } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { ApiError, bearer, recent, type RuntimeConfig, FirebaseSessionVerifier } from './security.js';
import { object } from './validation.js';
import { AccountRepository } from './repository.js';

const blocked = new Set<string>(JSON.parse(readFileSync(new URL('../../password-blocklist.json', import.meta.url), 'utf8')));
export function emailAddress(value: unknown): string {
  if (typeof value !== 'string' || value.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) throw new ApiError(400, 'invalid_email');
  return value.trim().toLowerCase();
}
export function newPassword(value: unknown): string {
  if (typeof value !== 'string' || [...value].length < 15 || value.length > 4096) throw new ApiError(400, 'password_policy');
  const hash = createHash('sha256').update(value).digest('hex');
  if (blocked.has(hash) || /^(.)(\1){14,}$/u.test(value) || /^(airzero[ _-]*strike|password|qwerty|1234567890)[\d!@#$ _-]*$/i.test(value)) {
    throw new ApiError(400, 'password_blocked');
  }
  return value; // Only transiently forwarded to Firebase; NEVER stored/logged.
}

export class MailLimiter {
  constructor(private readonly db: Firestore, private readonly scope: string,
    private readonly secret: string, private readonly now = Date.now) {}
  async allow(source: string, account: string, operation: string, interval = 60000, limit = 5): Promise<boolean> {
    const hash = (s: string) => createHmac('sha256', this.secret).update(s).digest('hex');
    const src = this.db.doc(`${this.scope}/emailLimits/${hash(`source:${source}`)}`);
    const dst = this.db.doc(`${this.scope}/emailLimits/${hash(`account:${account}:${operation}`)}`);
    return this.db.runTransaction(async (tx) => {
      const [s, a] = await tx.getAll(src, dst), now = this.now();
      const sourceData = s!.data(), accountData = a!.data();
      const count = sourceData && now - sourceData.startedAtMs < 900000 ? sourceData.count as number : 0;
      if (count >= 20) throw new ApiError(429, 'try_later');
      tx.set(src, { startedAtMs: count ? sourceData!.startedAtMs : now, count: count + 1, expiresAtMs: now + 900000 });
      if (accountData && now < accountData.nextAllowedMs) return false;
      const attempts = accountData && now - accountData.startedAtMs < 900000 ? accountData.count as number : 0;
      if (attempts >= limit) return false;
      tx.set(dst, { startedAtMs: attempts ? accountData!.startedAtMs : now, count: attempts + 1,
        nextAllowedMs: now + interval, expiresAtMs: now + 900000 });
      return true;
    });
  }
}

type Json = Record<string, any>;
export class EmailService {
  private readonly limiter: MailLimiter;
  readonly continueUrl: string;
  constructor(private readonly config: RuntimeConfig, private readonly auth: Auth,
    db: Firestore, private readonly verifier: FirebaseSessionVerifier,
    private readonly repository: AccountRepository, private readonly env: NodeJS.ProcessEnv) {
    const secret = config.mode === 'emulator' ? 'demo-only-mail-rate-fixture-not-a-production-secret' : env.AIRZERO_EMAIL_RATE_SECRET;
    this.continueUrl = `https://${config.projectId}.firebaseapp.com/__/auth/complete`;
    this.limiter = new MailLimiter(db, repository.scope, secret ?? 'unconfigured');
  }
  private ready(): void {
    if (this.config.mode === 'cloud' && (this.env.AIRZERO_EMAIL_SECURITY_READY !== 'true' ||
      !this.env.AIRZERO_FIREBASE_WEB_API_KEY || (this.env.AIRZERO_EMAIL_RATE_SECRET?.length ?? 0) < 32)) {
      throw new ApiError(503, 'email_setup_required');
    }
  }
  private async firebase(method: string, data: Json, proof?: string): Promise<Json> {
    const base = this.config.mode === 'emulator'
      ? 'http://127.0.0.1:9299/identitytoolkit.googleapis.com/v1/'
      : 'https://identitytoolkit.googleapis.com/v1/';
    try {
      const response = await fetch(`${base}${method}?key=${this.config.mode === 'emulator' ? 'demo-api-key' : this.env.AIRZERO_FIREBASE_WEB_API_KEY}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Firebase-Locale': 'ko',
          ...(proof ? { 'X-Firebase-AppCheck': proof } : {}) },
        body: JSON.stringify(data), signal: AbortSignal.timeout(12000), redirect: 'error',
      });
      const result = await response.json() as Json;
      if (!response.ok) {
        const code = String(result.error?.message ?? '').split(' : ')[0] ?? '';
        if (['INVALID_OOB_CODE', 'EXPIRED_OOB_CODE'].includes(code)) throw new ApiError(400, 'invalid_or_expired_link');
        if (['WEAK_PASSWORD', 'PASSWORD_DOES_NOT_MEET_REQUIREMENTS'].includes(code)) throw new ApiError(400, 'password_policy');
        if (method === 'accounts:sendOobCode' && ['EMAIL_NOT_FOUND', 'EMAIL_EXISTS', 'INVALID_EMAIL', 'USER_NOT_FOUND'].includes(code)) return { ignored: true };
        if (code === 'TOO_MANY_ATTEMPTS_TRY_LATER') throw new ApiError(429, 'try_later');
        throw new ApiError(503, 'email_service_unavailable');
      }
      return result;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(503, 'email_service_unavailable');
    }
  }
  async handle(path: string, body: unknown, authorization: unknown, proof: string | undefined, source: string): Promise<Json> {
    this.ready();
    await this.verifier.checkApp(proof);
    if (path === 'policy') return { minimumLength: 15, maximumLength: 4096, blockedListVersion: 1 };
    const begin = Date.now();
    // Equal response floor and shape for register/reset/change, including
    // duplicate or account-throttled requests. No existence lookup endpoint.
    const mail = ['register', 'reset-email', 'verification-email', 'change-email'].includes(path);
    try {
      if (path === 'register') {
        const p = object(body, ['email', 'password', 'consent']);
        const email = emailAddress(p.email), password = newPassword(p.password);
        if (p.consent !== true) throw new ApiError(400, 'consent_required');
        if (await this.limiter.allow(source, email, 'register')) {
          let created = false;
          try {
            const user = await this.auth.createUser({ email, password, emailVerified: false });
            await this.repository.markEmailPasswordAccount(user.uid);
            created = true;
          }
          catch (error) {
            if ((error as { code?: string }).code !== 'auth/email-already-exists') throw new ApiError(503, 'email_service_unavailable');
          }
          if (created) {
            const signed = await this.firebase('accounts:signInWithPassword', { email, password, returnSecureToken: true }, proof);
            if (!signed.idToken) throw new ApiError(503, 'email_service_unavailable');
            await this.firebase('accounts:sendOobCode', { requestType: 'VERIFY_EMAIL', idToken: signed.idToken, continueUrl: this.continueUrl }, proof);
          }
        }
      } else if (path === 'reset-email') {
        const p = object(body, ['email']), email = emailAddress(p.email);
        if (await this.limiter.allow(source, email, 'reset')) {
          const user = await this.auth.getUserByEmail(email).catch((error: { code?: string }) => {
            if (error.code === 'auth/user-not-found') return null;
            throw new ApiError(503, 'email_service_unavailable');
          });
          if (user && await this.repository.allowsPasswordAccount(user.uid, user.providerData.map((p) => p.providerId))) await this.firebase('accounts:sendOobCode', {
            requestType: 'PASSWORD_RESET', email, continueUrl: this.continueUrl }, proof);
        }
      } else if (path === 'verification-email' || path === 'change-email') {
        const p = object(body, path === 'change-email' ? ['email'] : []);
        const token = bearer(authorization), identity = await this.verifier.verifyForMail(token, proof);
        const user = await this.auth.getUser(identity.uid);
        if (identity.signInProvider !== 'password' || !await this.repository.allowsPasswordAccount(user.uid, user.providerData.map((p) => p.providerId))) {
          throw new ApiError(403, 'password_link_required');
        }
        if (path === 'change-email') recent(identity);
        if (await this.limiter.allow(source, identity.uid, path)) await this.firebase('accounts:sendOobCode', {
          requestType: path === 'change-email' ? 'VERIFY_AND_CHANGE_EMAIL' : 'VERIFY_EMAIL',
          idToken: token, ...(path === 'change-email' ? { newEmail: emailAddress(p.email) } : {}), continueUrl: this.continueUrl }, proof);
      } else if (path === 'check-action' || path === 'confirm-action') {
        const p = object(body, path === 'check-action' ? ['code', 'mode'] : ['code', 'mode', 'password']);
        if (typeof p.code !== 'string' || !/^[A-Za-z0-9_-]{16,2048}$/.test(p.code) ||
          !['verifyEmail', 'resetPassword', 'verifyAndChangeEmail'].includes(String(p.mode))) throw new ApiError(400, 'invalid_or_expired_link');
        // No per-code throttle: a bad caller cannot lock the legitimate link.
        if (!await this.limiter.allow(source, `action:${source}`, 'action', 0, 20)) throw new ApiError(429, 'try_later');
        const info = await this.firebase('accounts:resetPassword', { oobCode: p.code }, proof);
        const expected = p.mode === 'resetPassword' ? 'PASSWORD_RESET' : p.mode === 'verifyEmail' ? 'VERIFY_EMAIL' : 'VERIFY_AND_CHANGE_EMAIL';
        if (info.requestType !== expected || typeof info.email !== 'string') throw new ApiError(400, 'invalid_or_expired_link');
        let identity;
        if (p.mode !== 'resetPassword' || authorization) {
          identity = await this.verifier.verifyForMail(bearer(authorization), proof);
          const user = await this.auth.getUser(identity.uid);
          const owner = info.email;
          if (user.email?.toLowerCase() !== String(owner).toLowerCase()) throw new ApiError(403, 'link_account_mismatch');
          if (p.mode === 'verifyAndChangeEmail') recent(identity);
        }
        if (path === 'check-action') return { mode: p.mode, valid: true };
        if (p.mode === 'resetPassword') {
          const password = newPassword(p.password);
          const user = await this.auth.getUserByEmail(info.email);
          if (!await this.repository.allowsPasswordAccount(user.uid, user.providerData.map((p) => p.providerId))) {
            throw new ApiError(400, 'invalid_or_expired_link');
          }
          await this.firebase('accounts:resetPassword', { oobCode: p.code, newPassword: password }, proof);
          await this.auth.revokeRefreshTokens(user.uid);
          await this.repository.invalidateAuthSessions(user.uid);
          return { completed: true, signInRequired: true };
        }
        if (p.password !== undefined) throw new ApiError(400, 'invalid_input');
        await this.firebase('accounts:update', { oobCode: p.code }, proof);
        if (p.mode === 'verifyAndChangeEmail') {
          await this.auth.revokeRefreshTokens(identity!.uid);
          await this.repository.invalidateAuthSessions(identity!.uid);
        }
        return { completed: true, signInRequired: p.mode === 'verifyAndChangeEmail' };
      } else throw new ApiError(404, 'operation_not_available');
      return { accepted: true, retryAfterSeconds: 60 };
    } finally {
      if (mail) await pause(Math.max(0, 800 + randomInt(101) - (Date.now() - begin)));
    }
  }
}
