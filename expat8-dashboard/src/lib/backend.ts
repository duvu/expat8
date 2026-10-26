import crypto from 'node:crypto';

import { getAdminConfig } from './config';

type BackendRequestOptions = {
  method?: string;
  body?: unknown;
};

export class BackendError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
    this.name = 'BackendError';
  }
}

/**
 * Signed request to the backend (HMAC app credential + admin token).
 * Returns the raw Response; callers decide how to treat non-2xx statuses.
 */
export async function backendFetch(path: string, options: BackendRequestOptions = {}) {
  const config = getAdminConfig();
  if (!config.appId || !config.appSecret) {
    throw new Error(
      'Missing dashboard backend credentials: APP_CREDENTIAL_APP_ID and APP_CREDENTIAL_SECRET are required'
    );
  }
  const url = new URL(path, config.backendBaseUrl);
  const body = options.body === undefined ? undefined : JSON.stringify(options.body);
  const method = (options.method ?? (body ? 'POST' : 'GET')).toUpperCase();
  const timestamp = new Date().toISOString();
  const nonce = crypto.randomUUID();
  const contentSha256 = hashBody(body ?? '');
  const canonicalRequest = [
    'v1',
    method,
    canonicalPathWithSortedQuery(url),
    timestamp,
    nonce,
    contentSha256
  ].join('\n');

  const headers = new Headers({
    'content-type': 'application/json',
    'x-expat8-app-id': config.appId,
    'x-expat8-timestamp': timestamp,
    'x-expat8-nonce': nonce,
    'x-expat8-content-sha256': contentSha256,
    'x-expat8-signature': signCanonicalRequest(config.appSecret, canonicalRequest),
  });
  if (config.adminToken) {
    headers.set('x-expat8-admin-token', config.adminToken);
  }

  return fetch(url, { method, headers, body, cache: 'no-store' });
}

/** Signed request that throws a BackendError on any non-2xx response. */
export async function backendRequest<T = unknown>(path: string, options: BackendRequestOptions = {}): Promise<T> {
  const response = await backendFetch(path, options);
  if (!response.ok) {
    throw new BackendError(
      await readErrorMessage(response, `Backend request failed (HTTP ${response.status})`),
      response.status
    );
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}

export async function readErrorMessage(response: Response, fallback: string) {
  try {
    const body = await response.json() as { error?: string; message?: string };
    return body.message ?? body.error ?? fallback;
  } catch {
    return fallback;
  }
}

function hashBody(body: string) {
  return crypto.createHash('sha256').update(body).digest('base64url');
}

function signCanonicalRequest(secret: string, canonicalRequest: string) {
  const signature = crypto.createHmac('sha256', secret).update(canonicalRequest).digest('base64url');
  return `v1=${signature}`;
}

function canonicalPathWithSortedQuery(url: URL) {
  const sortedParams = [...url.searchParams.entries()].sort(([leftKey, leftValue], [rightKey, rightValue]) =>
    leftKey === rightKey ? leftValue.localeCompare(rightValue) : leftKey.localeCompare(rightKey)
  );
  const queryString = new URLSearchParams(sortedParams).toString();
  return queryString ? `${url.pathname}?${queryString}` : url.pathname;
}
