import assert from 'node:assert/strict';
import test from 'node:test';

import {
  InMemoryNonceCache,
  buildCanonicalRequest,
  canonicalPathWithSortedQuery,
  hashBody,
  signCanonicalRequest,
  verifyAppCredentialRequest
} from '../src/app_credentials.js';

const activeCredential = {
  appId: 'app_mobile_test',
  secret: 'test-secret',
  status: 'active'
};

const baseConfig = {
  appCredentials: [activeCredential],
  appCredentialTimestampSkewSeconds: 300,
  appCredentialNonceTtlSeconds: 300
};

test('canonicalizes query parameters by key and value', () => {
  const url = new URL('http://localhost/v1/learning/cards?target_language=en&limit=1&limit=0');

  assert.equal(
    canonicalPathWithSortedQuery(url),
    '/v1/learning/cards?limit=0&limit=1&target_language=en'
  );
});

test('hashes body and signs canonical requests', () => {
  const contentSha256 = hashBody(Buffer.from('{"device_id":"device_1"}'));
  const canonicalRequest = buildCanonicalRequest({
    method: 'post',
    url: new URL('http://localhost/v1/study-events/sync?b=2&a=1'),
    timestamp: '2026-05-04T10:30:00.000Z',
    nonce: 'nonce_1',
    contentSha256
  });

  assert.equal(
    canonicalRequest,
    [
      'v1',
      'POST',
      '/v1/study-events/sync?a=1&b=2',
      '2026-05-04T10:30:00.000Z',
      'nonce_1',
      contentSha256
    ].join('\n')
  );
  assert.match(signCanonicalRequest({ secret: activeCredential.secret, canonicalRequest }), /^v1=/);
});

test('verifies valid credentials and rejects tampering, expiry, unknown apps, and replay', () => {
  const now = new Date('2026-05-04T10:30:00.000Z');
  const url = new URL('http://localhost/v1/learning/cards');
  const rawBody = Buffer.from('{"device_id":"anonymous_test","limit":10}');
  const nonceCache = new InMemoryNonceCache();
  const headers = signedHeaders({
    method: 'POST',
    url,
    rawBody,
    timestamp: now.toISOString(),
    nonce: 'nonce_1'
  });

  assert.deepEqual(
    verifyAppCredentialRequest({
      method: 'POST',
      url,
      headers,
      rawBody,
      config: baseConfig,
      nonceCache,
      now
    }),
    { ok: true, appId: activeCredential.appId }
  );

  assert.equal(
    verifyAppCredentialRequest({
      method: 'POST',
      url,
      headers,
      rawBody,
      config: baseConfig,
      nonceCache,
      now
    }).ok,
    false
  );

  assert.equal(
    verifyAppCredentialRequest({
      method: 'POST',
      url: new URL('http://localhost/v1/learning/cards?limit=2'),
      headers: signedHeaders({
        method: 'POST',
        url,
        rawBody,
        timestamp: now.toISOString(),
        nonce: 'nonce_2'
      }),
      rawBody,
      config: baseConfig,
      nonceCache: new InMemoryNonceCache(),
      now
    }).ok,
    false
  );

  assert.equal(
    verifyAppCredentialRequest({
      method: 'POST',
      url,
      headers: signedHeaders({
        method: 'POST',
        url,
        rawBody,
        timestamp: '2026-05-04T10:20:00.000Z',
        nonce: 'nonce_3'
      }),
      rawBody,
      config: baseConfig,
      nonceCache: new InMemoryNonceCache(),
      now
    }).ok,
    false
  );

  assert.equal(
    verifyAppCredentialRequest({
      method: 'POST',
      url,
      headers: {
        ...signedHeaders({
          method: 'POST',
          url,
          rawBody,
          timestamp: now.toISOString(),
          nonce: 'nonce_4'
        }),
        'x-expat8-app-id': 'unknown_app'
      },
      rawBody,
      config: baseConfig,
      nonceCache: new InMemoryNonceCache(),
      now
    }).ok,
    false
  );
});

function signedHeaders({ method, url, rawBody, timestamp, nonce }) {
  const contentSha256 = hashBody(rawBody);
  const canonicalRequest = buildCanonicalRequest({
    method,
    url,
    timestamp,
    nonce,
    contentSha256
  });

  return {
    'x-expat8-app-id': activeCredential.appId,
    'x-expat8-timestamp': timestamp,
    'x-expat8-nonce': nonce,
    'x-expat8-content-sha256': contentSha256,
    'x-expat8-signature': signCanonicalRequest({
      secret: activeCredential.secret,
      canonicalRequest
    })
  };
}
