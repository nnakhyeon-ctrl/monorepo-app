import type { Auth, DecodedIdToken } from 'firebase-admin/auth';
import type { AppCheck } from 'firebase-admin/app-check';

export class ApiError extends Error {
  constructor(readonly status: number, readonly code: string) { super(code); }
}
export interface RuntimeConfig {
  mode: 'emulator' | 'cloud'; projectId: string; environment: 'dev' | 'prod';
  region: string; appIds: ReadonlySet<string>;
  serviceAccount?: string;
}
export const demoProject = 'demo-airzero-strike';
export const appName = 'airzero-strike';
export function loadConfig(env: NodeJS.ProcessEnv): RuntimeConfig {
  const emulator = env.FUNCTIONS_EMULATOR === 'true';
  if (emulator) {
    if (env.GCLOUD_PROJECT !== demoProject ||
        env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9299' ||
        env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8280') throw new Error('invalid_local_scope');
    return { mode: 'emulator', projectId: demoProject, environment: 'dev',
      region: 'asia-northeast3', appIds: new Set() };
  }
  if (env.FIREBASE_AUTH_EMULATOR_HOST || env.FIRESTORE_EMULATOR_HOST ||
      env.FIREBASE_DATABASE_EMULATOR_HOST || env.FIREBASE_STORAGE_EMULATOR_HOST) throw new Error('emulator_in_cloud');
  const projectId = env.AIRZERO_PROJECT_ID;
  const environment = env.AIRZERO_ENVIRONMENT;
  const region = env.AIRZERO_REGION;
  const serviceAccount = env.AIRZERO_SERVICE_ACCOUNT;
  const appIds = (env.AIRZERO_FIREBASE_APP_IDS ?? '').split(',').filter(Boolean);
  if (!projectId || projectId !== env.GCLOUD_PROJECT || projectId.startsWith('demo-') ||
      !/^airzero-strike-[a-z0-9-]+$/.test(projectId) ||
      !['dev', 'prod'].includes(environment ?? '') || !region || !/^[a-z]+-[a-z]+\d$/.test(region) ||
      !serviceAccount || !serviceAccount.endsWith(`@${projectId}.iam.gserviceaccount.com`) ||
      !/^airzero-auth-[a-z0-9-]+@airzero-strike-[a-z0-9-]+\.iam\.gserviceaccount\.com$/.test(serviceAccount) ||
      appIds.length === 0 || appIds.some((id) => !/^1:\d+:(android|ios):[a-f0-9]+$/.test(id))) {
    throw new Error('cloud_scope_not_configured');
  }
  return { mode: 'cloud', projectId, environment: environment as 'dev' | 'prod', region, appIds: new Set(appIds), serviceAccount };
}

export interface ProviderIdentity { provider: string; subject: string }
export interface Identity {
  uid: string; issuedAt: number; authTime: number; expiresAt: number;
  store: 'play' | 'app-store';
  providers: ProviderIdentity[];
  signInProvider?: string;
  passwordRequiresApproval?: boolean;
}
export interface SessionVerifier { verify(idToken: string, appCheckToken?: string): Promise<Identity> }

export class FirebaseSessionVerifier implements SessionVerifier {
  constructor(private readonly auth: Auth, private readonly appCheck: AppCheck,
    private readonly config: RuntimeConfig, private readonly now = Date.now,
    private readonly socialGrant?: (uid: string, grant: string, authTime: number) => Promise<ProviderIdentity>) {}
  async verify(idToken: string, appCheckToken?: string): Promise<Identity> {
    return this.inspect(idToken, appCheckToken, true);
  }
  async checkApp(appCheckToken?: string): Promise<Identity['store']> {
    if (this.config.mode === 'emulator') return 'play';
    if (!appCheckToken) throw new ApiError(401, 'invalid_session');
    try {
      const proof = await this.appCheck.verifyToken(appCheckToken);
      if (!this.config.appIds.has(proof.appId)) throw new ApiError(403, 'app_scope_denied');
      return proof.appId.includes(':ios:') ? 'app-store' : 'play';
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(401, 'invalid_session');
    }
  }
  /** Unverified email sessions may only request/consume email verification.
   * This method NEVER authorizes private game data. */
  async verifyForMail(idToken: string, appCheckToken?: string): Promise<Identity> {
    return this.inspect(idToken, appCheckToken, false);
  }
  private async inspect(idToken: string, appCheckToken: string | undefined, requireVerified: boolean): Promise<Identity> {
    try {
      const store = await this.checkApp(appCheckToken);
      // true checks revoked credentials and disabled users, not just JWT decode.
      const token: DecodedIdToken = await this.auth.verifyIdToken(idToken, true);
      const nowSec = Math.floor(this.now() / 1000);
      if (token.aud !== this.config.projectId || token.iss !== `https://securetoken.google.com/${this.config.projectId}` ||
          token.sub !== token.uid || !/^[A-Za-z0-9_-]{1,128}$/.test(token.uid) ||
          !Number.isInteger(token.exp) || token.exp <= nowSec ||
          !Number.isInteger(token.iat) || token.iat > nowSec + 30 ||
          !Number.isInteger(token.auth_time) || token.auth_time > nowSec + 30 ||
          token.auth_time > token.iat) throw new ApiError(401, 'invalid_session');
      const user = await this.auth.getUser(token.uid);
      if (user.disabled) throw new ApiError(401, 'invalid_session');
      const signIn = token.firebase.sign_in_provider;
      if (signIn === 'custom' && typeof token.azSocialGrant === 'string' && this.socialGrant) {
        const social = await this.socialGrant(user.uid, token.azSocialGrant, token.auth_time);
        const native = user.providerData.filter((p) => p.providerId === 'password')
          .map(() => ({ provider: 'password', subject: user.uid }));
        return { uid: user.uid, store, signInProvider: social.provider, issuedAt: token.iat,
          authTime: token.auth_time, expiresAt: token.exp * 1000, providers: [...native, social] };
      }
      if (signIn === 'anonymous') throw new ApiError(403, 'account_connection_required');
      if (requireVerified && signIn === 'password' && (!user.emailVerified || token.email_verified !== true)) {
        throw new ApiError(403, 'email_verification_required');
      }
      if (signIn !== 'password') {
        // Social login requires this app's verified grant, never trusted-email auto-linking.
        throw new ApiError(403, 'provider_not_connected');
      }
      // Direct Firebase credential linking must not create app provider bindings.
      // Only SocialService's challenge + recent-auth transaction can do that.
      const providers = user.providerData.filter((p) => p.providerId === 'password')
        .map(() => ({ provider: 'password', subject: user.uid }));
      if (!providers.some((p) => p.provider === signIn) ||
          providers.some((p) => !p.subject || p.subject.length > 256)) throw new ApiError(401, 'invalid_session');
      return { uid: user.uid, store, signInProvider: signIn, issuedAt: token.iat, authTime: token.auth_time,
        expiresAt: token.exp * 1000, providers,
        passwordRequiresApproval: user.providerData.some((p) => p.providerId !== 'password') };
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(401, 'invalid_session');
    }
  }
}

export function bearer(value: unknown): string {
  if (typeof value !== 'string' || value.length > 8192 || !/^Bearer [A-Za-z0-9._-]+$/.test(value)) {
    throw new ApiError(401, 'invalid_session');
  }
  return value.slice(7);
}
export function recent(identity: Identity, now = Date.now()): void {
  if (now - identity.authTime * 1000 > 300000) throw new ApiError(401, 'recent_authentication_required');
}
