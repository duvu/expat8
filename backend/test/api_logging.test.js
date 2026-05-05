import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { createLogger } from '../src/logger.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('request lifecycle logs include request correlation id', async (t) => {
  const lines = [];
  const logger = createLogger({
    level: 'debug',
    component: 'api-test',
    stream: { write: (line) => lines.push(line) }
  });
  const server = http.createServer(
    createApp({
      store: new WordStore({ seed: false }),
      generationService: null,
      config: loadTestConfig(),
      logger
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const requestId = 'req_test_123';
  const url = `${baseUrl}/v1/words/recent?limit=1&target_language=en`;
  const response = await fetch(url, signedFetchOptions(url, {
    headers: {
      'x-request-id': requestId
    }
  }));

  assert.equal(response.status, 200);

  const events = lines.map((line) => JSON.parse(line));
  const started = events.find((event) => event.event === 'request_started');
  const completed = events.find((event) => event.event === 'request_completed');

  assert.equal(started.request_id, requestId);
  assert.equal(completed.request_id, requestId);
});

test('error logs redact sensitive values', async (t) => {
  const lines = [];
  const logger = createLogger({
    level: 'debug',
    component: 'api-test',
    stream: { write: (line) => lines.push(line) }
  });
  const store = {
    async recentWords() {
      throw new Error('db query failed secret=my-secret token=abc123');
    }
  };

  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig(),
      logger
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const url = `${baseUrl}/v1/words/recent?limit=1&target_language=en`;
  const response = await fetch(url, signedFetchOptions(url));

  assert.equal(response.status, 500);

  const events = lines.map((line) => JSON.parse(line));
  const failed = events.find((event) => event.event === 'request_failed');

  assert.ok(failed);
  assert.equal(failed.error.message.includes('[REDACTED]'), true);
  assert.equal(failed.error.message.includes('my-secret'), false);
});

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, () => resolve());
  });
}
