import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { WordStore } from '../src/word_store.js';

test('serves word feed, recent words, and idempotent sync', async (t) => {
  const store = new WordStore();
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadConfig({})
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const next = await fetchJson(`${baseUrl}/v1/words/next?limit=1&target_language=en`);
  assert.equal(next.items.length, 1);
  assert.equal(next.items[0].language, 'en');

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

function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

async function fetchJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json();
}
