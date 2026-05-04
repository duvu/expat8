import assert from 'node:assert/strict';
import test from 'node:test';

import { loadConfig } from '../src/config.js';

test('loads database URL and deployment LiteLLM defaults from environment', () => {
  const config = loadConfig({
    DATABASE_URL: 'postgres://expat8:secret@db:5432/expat8'
  });

  assert.equal(config.databaseUrl, 'postgres://expat8:secret@db:5432/expat8');
  assert.equal(config.liteLLMBaseUrl, 'https://lite.x51.vn');
});

test('loads app credential security settings from environment', () => {
  const config = loadConfig({
    APP_CREDENTIALS_JSON: JSON.stringify([
      { appId: 'app_mobile_test', secret: 'test-secret', status: 'active' },
      { appId: 'app_mobile_old', secret: 'old-secret', status: 'revoked' }
    ]),
    APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS: '120',
    APP_CREDENTIAL_NONCE_TTL_SECONDS: '180',
    APP_CREDENTIAL_GET_BODY_LIMIT_BYTES: '0',
    APP_CREDENTIAL_POST_BODY_LIMIT_BYTES: '1024'
  });

  assert.deepEqual(config.appCredentials, [
    { appId: 'app_mobile_test', secret: 'test-secret', status: 'active' },
    { appId: 'app_mobile_old', secret: 'old-secret', status: 'revoked' }
  ]);
  assert.equal(config.appCredentialTimestampSkewSeconds, 120);
  assert.equal(config.appCredentialNonceTtlSeconds, 180);
  assert.equal(config.appCredentialGetBodyLimitBytes, 0);
  assert.equal(config.appCredentialPostBodyLimitBytes, 1024);
});

test('rejects malformed app credential configuration', () => {
  assert.throws(
    () =>
      loadConfig({
        APP_CREDENTIALS_JSON: JSON.stringify([
          { appId: 'app_mobile_test', secret: '', status: 'active' }
        ])
      }),
    /APP_CREDENTIALS_JSON/
  );
});
