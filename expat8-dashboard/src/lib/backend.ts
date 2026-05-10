import crypto from 'node:crypto';

import { getAdminConfig } from './config';

type BackendRequestOptions = {
  method?: string;
  headers?: Record<string, string>;
  body?: unknown;
};

export async function backendFetch(path: string, options: BackendRequestOptions = {}) {
  const config = getAdminConfig();
  if (!config.appId || !config.appSecret) {
    throw new Error(
      'Missing dashboard backend credentials: APP_CREDENTIAL_APP_ID and APP_CREDENTIAL_SECRET are required'
    );
  }
  const url = new URL(path, config.backendBaseUrl);
  const body = options.body === undefined ? undefined : JSON.stringify(options.body);
  const timestamp = new Date().toISOString();
  const nonce = crypto.randomUUID();
  const contentSha256 = hashBody(body ?? '');
  const canonicalRequest = [
    'v1',
    (options.method ?? (body ? 'POST' : 'GET')).toUpperCase(),
    canonicalPathWithSortedQuery(url),
    timestamp,
    nonce,
    contentSha256
  ].join('\n');
  const signature = signCanonicalRequest(config.appSecret, canonicalRequest);

  const headers = new Headers(options.headers);
  headers.set('content-type', 'application/json');
  headers.set('x-expat8-app-id', config.appId);
  headers.set('x-expat8-timestamp', timestamp);
  headers.set('x-expat8-nonce', nonce);
  headers.set('x-expat8-content-sha256', contentSha256);
  headers.set('x-expat8-signature', signature);
  if (config.adminToken) {
    headers.set('x-expat8-admin-token', config.adminToken);
  }

  return fetch(url, {
    method: options.method ?? (body ? 'POST' : 'GET'),
    headers,
    body
  });
}

function hashBody(body: string) {
  return crypto.createHash('sha256').update(body).digest('base64url');
}

function signCanonicalRequest(secret: string, canonicalRequest: string) {
  const signature = crypto.createHmac('sha256', secret).update(canonicalRequest).digest('base64url');
  return `v1=${signature}`;
}

function canonicalPathWithSortedQuery(url: URL) {
  const sortedParams = [...url.searchParams.entries()].sort(([leftKey, leftValue], [rightKey, rightValue]) => {
    if (leftKey === rightKey) {
      return leftValue.localeCompare(rightValue);
    }
    return leftKey.localeCompare(rightKey);
  });

  const query = new URLSearchParams();
  for (const [key, value] of sortedParams) {
    query.append(key, value);
  }

  const queryString = query.toString();
  return queryString ? `${url.pathname}?${queryString}` : url.pathname;
}
