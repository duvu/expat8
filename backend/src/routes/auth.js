import express from 'express';
import { rateLimitMiddleware } from '../rate_limit.js';
import {
  DuplicateUserError,
  InvalidCredentialsError,
  InvalidRegistrationInputError,
  normalizeUserIdentifier
} from '../user_identity.js';
import { asyncHandler, bearerToken } from './helpers.js';

export function createAuthRouter({ store, _config, rateLimiters = {} }) {
  const { registerLimiter, signInLimiter, authIpLimiter } = rateLimiters;
  const router = express.Router();

  router.post(
    '/users/register',
    ...authRateLimits({ ipLimiter: authIpLimiter, accountLimiter: registerLimiter, keyPrefix: 'register' }),
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      try {
        const result = await store.registerUser({
          identifier: body.identifier,
          password: body.password,
          displayName: body.display_name ?? null,
          deviceId: body.device_id ?? null
        });
        return response.status(201).json(userSessionResponse(result));
      } catch (error) {
        if (error instanceof DuplicateUserError) {
          return response.status(409).json({ error: 'user_exists' });
        }
        if (error instanceof InvalidRegistrationInputError) {
          return response.status(400).json({ error: 'bad_request' });
        }
        throw error;
      }
    })
  );

  router.post(
    '/users/sign-in',
    ...authRateLimits({ ipLimiter: authIpLimiter, accountLimiter: signInLimiter, keyPrefix: 'signin' }),
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      try {
        const result = await store.createUserSession({
          identifier: body.identifier,
          password: body.password,
          deviceId: body.device_id ?? null
        });
        return response.json(userSessionResponse(result));
      } catch (error) {
        if (error instanceof InvalidCredentialsError) {
          return response.status(401).json({
            error: 'invalid_credentials',
            ...(error.reason ? { reason: error.reason } : {})
          });
        }
        throw error;
      }
    })
  );

  router.post(
    '/users/sign-out',
    asyncHandler(async (request, response) => {
      const sessionToken = bearerToken(request);
      if (!sessionToken) {
        request.log?.warn('sign_out_failed', { reason: 'missing_session_token' });
        return response.status(401).json({ error: 'invalid_session' });
      }
      const result = await store.revokeUserSession({ sessionToken });
      if (!result.revoked) {
        request.log?.warn('sign_out_failed', { reason: 'invalid_session' });
        return response.status(401).json({ error: 'invalid_session' });
      }
      return response.json({ success: true });
    })
  );

  return router;
}

// The IP limiter runs first so a single source cannot mint unbounded
// per-account buckets by cycling identifiers.
function authRateLimits({ ipLimiter, accountLimiter, keyPrefix }) {
  const middlewares = [];
  if (ipLimiter) {
    middlewares.push(rateLimitMiddleware(ipLimiter, { keyPrefix: 'auth-ip', keyFn: clientIp }));
  }
  if (accountLimiter) {
    middlewares.push(rateLimitMiddleware(accountLimiter, { keyPrefix, keyFn: buildAuthAccountRateLimitKey }));
  }
  return middlewares;
}

function clientIp(request) {
  return request.ip || 'unknown';
}

function buildAuthAccountRateLimitKey(request) {
  const identifier = normalizeUserIdentifier(request.body?.identifier).slice(0, 320) || '-';
  return `${clientIp(request)}|${identifier}`;
}

function userSessionResponse({ user, sessionToken }) {
  return {
    user_id: user.id,
    identifier: user.identifier,
    display_name: user.display_name,
    session_token: sessionToken
  };
}
