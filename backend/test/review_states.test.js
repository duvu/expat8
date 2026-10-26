import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

async function startApp(t, store) {
  const server = http.createServer(createApp({ store, generationService: null, config: loadTestConfig() }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  return `http://127.0.0.1:${server.address().port}`;
}

async function call(url, options = {}) {
  const response = await fetch(url, signedFetchOptions(url, options));
  assert.equal(response.ok, true, `${response.status} ${url}`);
  return response.json();
}

function seedWords(store, count) {
  for (let index = 0; index < count; index += 1) {
    store.insertWord({
      id: `word_${index}`,
      term: `term${index}`,
      language: 'en',
      meaning_vi: `nghia ${index}`,
      part_of_speech: 'noun',
      ipa: '/t/',
      vietnamese_pronunciation: 't',
      example: `term${index} example`,
      example_vi: 'vi du',
      difficulty: 'A1',
      topics: []
    });
  }
}

test('a second device of the same learner pulls every SRS state page by page', async (t) => {
  const store = new WordStore({ seed: false });
  seedWords(store, 3);
  const baseUrl = await startApp(t, store);
  const { session_token: token } = await call(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ identifier: 'parent@example.com', password: 'correct horse battery staple' })
  });
  const auth = { authorization: `Bearer ${token}` };

  // Studied offline on the phone, uploaded in one sync, newest event first.
  const ratings = ['easy', 'too_hard', 'too_easy'];
  await call(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...auth },
    body: JSON.stringify({
      device_id: 'phone',
      events: ratings
        .map((rating, index) => ({
          client_event_id: `evt_${index}`,
          server_word_id: `word_${index}`,
          rating,
          occurred_at: `2026-01-0${index + 1}T08:00:00.000Z`
        }))
        .reverse()
    })
  });

  // The tablet starts from scratch and pages through with a cursor.
  const pull = (cursor) =>
    call(`${baseUrl}/v1/review/states?device_id=tablet&language=en&limit=2${cursor ? `&cursor=${cursor}` : ''}`, {
      headers: auth
    });
  const first = await pull();
  assert.equal(first.items.length, 2);
  assert.equal(first.has_more, true);
  const second = await pull(first.next_cursor);
  assert.equal(second.items.length, 1);
  assert.equal(second.has_more, false);
  // Caught up: the last cursor yields nothing new and is echoed back.
  const third = await pull(second.next_cursor);
  assert.deepEqual(third, { items: [], next_cursor: second.next_cursor, has_more: false });

  const byWord = new Map([...first.items, ...second.items].map((item) => [item.word.server_word_id, item]));
  assert.equal(byWord.size, 3);
  assert.equal(byWord.get('word_0').state.next_review_at, '2026-01-03T08:00:00.000Z');
  assert.equal(byWord.get('word_1').state.status, 'learning');
  assert.equal(byWord.get('word_1').state.lapses, 1);
  assert.equal(byWord.get('word_2').word.term, 'term2');

  // Signed-out use of the phone is a separate owner (a malformed cursor just restarts from the top).
  const anonymous = await call(`${baseUrl}/v1/review/states?device_id=phone&language=en&cursor=not-a-cursor`);
  assert.deepEqual(anonymous, { items: [], next_cursor: 'not-a-cursor', has_more: false });
});

test('a later rating moves the state past the cursor', async (t) => {
  const store = new WordStore({ seed: false });
  seedWords(store, 1);
  const baseUrl = await startApp(t, store);
  const rate = (id, rating, at) =>
    call(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_id: 'kid-tablet', client_event_id: id, word_id: 'word_0', rating, occurred_at: at })
    });
  const pull = (cursor = '') =>
    call(`${baseUrl}/v1/review/states?device_id=kid-tablet&language=en&limit=1&cursor=${cursor}`);

  await rate('a', 'easy', '2026-01-01T08:00:00.000Z');
  const first = await pull();
  assert.equal(first.items[0].state.reps, 1);
  await new Promise((resolve) => setTimeout(resolve, 2));
  await rate('b', 'easy', '2026-01-03T08:00:00.000Z');
  const next = await pull(first.next_cursor);
  assert.equal(next.items.length, 1);
  assert.equal(next.items[0].state.reps, 2);
  assert.equal(next.items[0].state.interval_days, 6);
});
