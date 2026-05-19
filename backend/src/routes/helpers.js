/**
 * Shared route helper utilities.
 * Used by all route modules to avoid duplication.
 */

export function asyncHandler(handler) {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}

export function bearerToken(request) {
  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(/\s+/);
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

export async function resolveOptionalUserSession({ request, response, store }) {
  const token = bearerToken(request);
  if (!token) {
    return null;
  }
  const session = await store.resolveUserSession({ sessionToken: token });
  if (!session) {
    request.log?.warn('session_resolution_failed', { reason: 'invalid_session' });
    response.status(401).json({ error: 'invalid_session' });
    return false;
  }
  return session;
}

export async function resolveRequiredUserSession({ request, response, store }) {
  const session = await resolveOptionalUserSession({ request, response, store });
  if (session === false) {
    return null;
  }
  if (!session) {
    response.status(401).json({ error: 'invalid_session' });
    return null;
  }
  return session;
}

export function clampLimit(raw, min, max) {
  const parsed = Number.parseInt(raw ?? `${min}`, 10);
  if (Number.isNaN(parsed)) {
    return min;
  }
  return Math.max(min, Math.min(max, parsed));
}

export function hasAdminAccess({ request, config }) {
  if (config.adminApiTokens.size === 0) {
    return false;
  }
  const token = request.get('x-expat8-admin-token') ?? request.get('x-admin-token');
  return typeof token === 'string' && config.adminApiTokens.has(token);
}
