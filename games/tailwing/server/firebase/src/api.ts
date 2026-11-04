import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'firebase-functions/v2/https';
import { AccountRepository } from './repository.js';
import { ApiError, bearer, type RuntimeConfig, type SessionVerifier } from './security.js';
import { defaultPreferences, guestProgress, integer, object, operation, preferences } from './validation.js';
import type { EmailService } from './email.js';
import type { SocialService } from './social.js';
import type { AccountService } from './account.js';
import { deletionPortal } from './deletion-portal.js';
import type { BillingService } from './billing.js';

export function createApi(config: RuntimeConfig, verifier: SessionVerifier, repository: AccountRepository,
    log: (code: string, status: number) => void = () => {}, email?: EmailService, social?: SocialService, account?: AccountService,
    billing?: Pick<BillingService, 'handle' | 'background'>) {
  return async (req: Request, res: Response): Promise<void> => {
    res.set({ 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    try {
      if (config.mode === 'cloud' && req.protocol !== 'https') throw new ApiError(400, 'https_required');
      if (Object.keys(req.query).length || req.rawBody?.length > 32768) throw new ApiError(400, 'invalid_input');
      if (req.method !== 'GET' && !req.is('application/json')) throw new ApiError(415, 'json_required');
      const path = req.path;
      if (billing && path.startsWith('/v1/billing/notifications/') && req.method === 'POST') {
        res.json(await billing.background(path.slice('/v1/billing/notifications/'.length), req.body, req.headers.authorization)); return;
      }
      if (billing && path === '/v1/billing/maintenance' && req.method === 'POST') {
        object(req.body, []);
        res.json(await billing.background('maintenance', {}, req.headers.authorization)); return;
      }
      if (billing && ((path === '/v1/public/billing-policy' && req.method === 'GET') ||
          (path === '/v1/billing/status' && req.method === 'GET') ||
          (path === '/v1/me/entitlement' && req.method === 'GET') ||
          (['/v1/billing/intent', '/v1/billing/verify'].includes(path) && req.method === 'POST'))) {
        res.json(await billing.handle(path === '/v1/public/billing-policy' ? 'policy' :
          path === '/v1/me/entitlement' ? 'status' : path.slice('/v1/billing/'.length), req.body,
          req.headers.authorization, req.get('X-Firebase-AppCheck'), req.get('X-Airzero-Session'))); return;
      }
      if (path === '/account-deletion' && req.method === 'GET') {
        const page = deletionPortal(config.mode === 'emulator');
        res.set(page.headers).type('html').send(page.html);
        return;
      }
      if (account && ((path === '/v1/public/account-policy' && req.method === 'GET') ||
          (path === '/v1/me/account' && req.method === 'GET') ||
          (path.startsWith('/v1/account/deletion/') && req.method === 'POST'))) {
        res.json(await account.handle(path === '/v1/public/account-policy' ? 'policy' :
          path === '/v1/me/account' ? 'profile' : path.slice('/v1/account/deletion/'.length), req.body,
          req.headers.authorization, req.get('X-Firebase-AppCheck'), req.get('X-Airzero-Session'), req.ip ?? 'unavailable'));
        return;
      }
      if (social && ((path === '/v1/public/social-policy' && req.method === 'GET') ||
          (path.startsWith('/v1/social/') && req.method === 'POST'))) {
        res.json(await social.handle(path === '/v1/public/social-policy' ? 'policy' : path.slice('/v1/social/'.length),
          req.body, req.headers.authorization, req.get('X-Firebase-AppCheck'), req.get('X-Airzero-Session'), req.ip ?? 'unavailable'));
        return;
      }
      if (email && ((path === '/v1/public/email-policy' && req.method === 'GET') ||
        (path.startsWith('/v1/auth/') && req.method === 'POST'))) {
        const action = path === '/v1/public/email-policy' ? 'policy' : path.slice('/v1/auth/'.length);
        res.json(await email.handle(action, req.body, req.headers.authorization,
          req.get('X-Firebase-AppCheck'), req.ip ?? 'unavailable'));
        return;
      }
      if (path === '/v1/public/catalog' && req.method === 'GET') {
        res.json(await repository.publicCatalog()); return;
      }
      const identity = await verifier.verify(bearer(req.headers.authorization), req.get('X-Firebase-AppCheck'));
      if (path === '/v1/session/start' && req.method === 'POST') {
        object(req.body, []);
        res.json(await repository.start(identity)); return;
      }
      const handle = req.get('X-Airzero-Session') ?? '';
      let result: Record<string, unknown>;
      if (path === '/v1/session/end' && req.method === 'POST') {
        object(req.body, []);
        result = await repository.logout(identity, handle);
      } else if (path === '/v1/me/progress' && req.method === 'GET') {
        result = await repository.read(identity, handle, 'progress');
      } else if (path === '/v1/me/entitlement' && req.method === 'GET') {
        result = await repository.entitlement(identity, handle);
      } else if (path === '/v1/me/import-preview' && req.method === 'POST') {
        object(req.body, []);
        result = await repository.preview(identity, handle);
      } else if (path === '/v1/me/import-guest' && req.method === 'POST') {
        const p = object(req.body, ['guest', 'operationId', 'expectedRevision', 'generation', 'confirmed']);
        result = await repository.importGuest(identity, handle, operation(p.operationId), integer(p.expectedRevision),
          integer(p.generation), guestProgress(p.guest), p.confirmed === true);
      } else if (path === '/v1/me/preferences' && req.method === 'GET') {
        result = await repository.read(identity, handle, 'preferences');
      } else if (path === '/v1/me/preferences' && ['PUT', 'DELETE'].includes(req.method)) {
        const reset = req.method === 'DELETE';
        const p = object(req.body, reset ? ['operationId', 'expectedRevision', 'generation']
          : ['operationId', 'expectedRevision', 'generation', 'settings']);
        result = await repository.savePreferences(identity, handle, operation(p.operationId),
          integer(p.expectedRevision), integer(p.generation), reset ? defaultPreferences : preferences(p.settings), reset);
      } else {
        throw new ApiError(404, 'operation_not_available');
      }
      res.json(result);
    } catch (error) {
      const safe = error instanceof ApiError ? error : new ApiError(503, 'service_unavailable');
      log(safe.code, safe.status); // Never request/URL/token/UID/email/error object.
      res.status(safe.status).json({ error: safe.code, requestId: randomUUID() });
    }
  };
}
