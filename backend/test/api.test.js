import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('serves word feed, recent words, and idempotent sync', async (t) => {
  const store = new WordStore();
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const next = await fetchJson(`${baseUrl}/v1/words/next?limit=1&target_language=en`);
  assert.equal(next.items.length, 1);
  assert.equal(next.items[0].language, 'en');

  const nextDifferent = await fetchJson(
    `${baseUrl}/v1/words/next?limit=1&target_language=en&exclude_server_word_id=${next.items[0].server_word_id}`
  );
  assert.equal(nextDifferent.items.length, 1);
  assert.notEqual(nextDifferent.items[0].server_word_id, next.items[0].server_word_id);

  const excludedAll = await fetchJson(
    `${baseUrl}/v1/words/next?limit=1&target_language=en&exclude_server_word_id=${next.items[0].server_word_id}&exclude_server_word_id=${nextDifferent.items[0].server_word_id}`
  );
  assert.deepEqual(excludedAll.items, []);

  const recent = await fetchJson(`${baseUrl}/v1/words/recent?limit=2000&target_language=en`);
  assert.ok(recent.items.length <= 1000);

  const sync = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_1',
      events: [
        {
          client_event_id: 'evt_1',
          server_word_id: next.items[0].server_word_id,
          local_word_id: 'local_1',
          rating: 'remembered',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });
  assert.deepEqual(sync.accepted_event_ids, ['evt_1']);

  const retry = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_1',
      events: [
        {
          client_event_id: 'evt_1',
          server_word_id: next.items[0].server_word_id,
          local_word_id: 'local_1',
          rating: 'remembered',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });
  assert.deepEqual(retry.accepted_event_ids, ['evt_1']);
  assert.equal(store.studyEventsByClientId.size, 1);
});

test('serves API with an async store implementation', async (t) => {
  const store = new AsyncStoreAdapter(new WordStore());
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const next = await fetchJson(`${baseUrl}/v1/words/next?limit=1&target_language=en`);
  assert.equal(next.items.length, 1);

  const sync = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_async',
      events: [
        {
          client_event_id: 'evt_async_1',
          server_word_id: next.items[0].server_word_id,
          local_word_id: 'local_async_1',
          rating: 'remembered',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });

  assert.deepEqual(sync.accepted_event_ids, ['evt_async_1']);
});

test('protects v1 routes with app credentials while leaving health open', async (t) => {
  const store = new CountingStore();
  const generationService = {
    calls: 0,
    async generateAndStore() {
      this.calls += 1;
      return [];
    }
  };
  const server = http.createServer(
    createApp({
      store,
      generationService,
      config: loadTestConfig({
        APP_CREDENTIAL_POST_BODY_LIMIT_BYTES: '32'
      })
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const health = await fetch(`${baseUrl}/health`);
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { ok: true });

  const unsigned = await fetch(`${baseUrl}/v1/words/next?limit=1`);
  assert.equal(unsigned.status, 400);
  assert.deepEqual(await unsigned.json(), { error: 'bad_request' });
  assert.equal(store.findNewWordsCalls, 0);
  assert.equal(generationService.calls, 0);

  const valid = await fetch(`${baseUrl}/v1/words/next?limit=1`, signedFetchOptions(`${baseUrl}/v1/words/next?limit=1`));
  assert.equal(valid.status, 200);
  assert.equal(store.findNewWordsCalls, 1);

  const tampered = await fetch(
    `${baseUrl}/v1/words/next?limit=2`,
    signedFetchOptions(`${baseUrl}/v1/words/next?limit=2`, {}, {
      signUrl: `${baseUrl}/v1/words/next?limit=1`
    })
  );
  assert.equal(tampered.status, 400);
  assert.deepEqual(await tampered.json(), { error: 'bad_request' });

  const expired = await fetch(
    `${baseUrl}/v1/words/next?limit=1`,
    signedFetchOptions(`${baseUrl}/v1/words/next?limit=1`, {}, {
      timestamp: '2026-05-04T10:20:00.000Z'
    })
  );
  assert.equal(expired.status, 400);

  const unknownApp = await fetch(
    `${baseUrl}/v1/words/next?limit=1`,
    signedFetchOptions(`${baseUrl}/v1/words/next?limit=1`, {}, {
      appId: 'unknown_app'
    })
  );
  assert.equal(unknownApp.status, 400);

  const replayOptions = signedFetchOptions(`${baseUrl}/v1/words/next?limit=1`, {}, {
    nonce: 'replay_nonce'
  });
  assert.equal((await fetch(`${baseUrl}/v1/words/next?limit=1`, replayOptions)).status, 200);
  assert.equal((await fetch(`${baseUrl}/v1/words/next?limit=1`, replayOptions)).status, 400);

  const oversizedBody = JSON.stringify({ device_id: 'device_1', events: [], padding: 'too-large' });
  const oversized = await fetch(
    `${baseUrl}/v1/study-events/sync`,
    signedFetchOptions(`${baseUrl}/v1/study-events/sync`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: oversizedBody
    })
  );
  assert.equal(oversized.status, 400);
});

test('rejects invalid sync credentials before parsing study event payloads', async (t) => {
  const store = new CountingStore();
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const response = await fetch(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{not-json'
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'bad_request' });
  assert.equal(store.syncStudyEventsCalls, 0);
});

class AsyncStoreAdapter {
  constructor(store) {
    this.store = store;
  }

  async insertWord(input) {
    return this.store.insertWord(input);
  }

  async findNewWords(input) {
    return this.store.findNewWords(input);
  }

  async recentWords(input) {
    return this.store.recentWords(input);
  }

  async syncStudyEvents(input) {
    return this.store.syncStudyEvents(input);
  }
}

function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

async function fetchJson(url, options) {
  const response = await fetch(url, signedFetchOptions(url, options));
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json();
}

class CountingStore extends AsyncStoreAdapter {
  constructor() {
    super(new WordStore());
    this.findNewWordsCalls = 0;
    this.syncStudyEventsCalls = 0;
  }

  async findNewWords(input) {
    this.findNewWordsCalls += 1;
    return super.findNewWords(input);
  }

  async syncStudyEvents(input) {
    this.syncStudyEventsCalls += 1;
    return super.syncStudyEvents(input);
  }
}
