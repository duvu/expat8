import { buildCanonicalRequest, hashBody, signCanonicalRequest } from '../../src/app_credentials.js';
import { loadConfig } from '../../src/config.js';

export const testAppCredential = {
  appId: 'app_mobile_test',
  secret: 'test-secret',
  status: 'active'
};

let nonceCounter = 0;

export function loadTestConfig(env = {}) {
  return loadConfig({
    APP_CREDENTIALS_JSON: JSON.stringify([testAppCredential]),
    ...env
  });
}

export function signedFetchOptions(url, options = {}, overrides = {}) {
  const method = (options.method ?? 'GET').toUpperCase();
  const rawBody = rawBodyBuffer(options.body);
  const timestamp = overrides.timestamp ?? new Date().toISOString();
  const nonce = overrides.nonce ?? `test_nonce_${++nonceCounter}`;
  const appId = overrides.appId ?? testAppCredential.appId;
  const secret = overrides.secret ?? testAppCredential.secret;
  const signUrl = new URL(overrides.signUrl ?? url);
  const contentSha256 = overrides.contentSha256 ?? hashBody(rawBody);
  const canonicalRequest = buildCanonicalRequest({
    method,
    url: signUrl,
    timestamp,
    nonce,
    contentSha256
  });

  return {
    ...options,
    method,
    headers: {
      ...(options.headers ?? {}),
      'x-expat8-app-id': appId,
      'x-expat8-timestamp': timestamp,
      'x-expat8-nonce': nonce,
      'x-expat8-content-sha256': contentSha256,
      'x-expat8-signature': signCanonicalRequest({ secret, canonicalRequest })
    }
  };
}

function rawBodyBuffer(body) {
  if (!body) {
    return Buffer.alloc(0);
  }
  if (Buffer.isBuffer(body)) {
    return body;
  }
  return Buffer.from(String(body));
}
