import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import pg from 'pg';

import { createApp } from '../src/app.js';
import { migrateDatabase } from '../src/migrations.js';
import { PostgresWordStore } from '../src/postgres_word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

const testDatabaseUrl = process.env.TEST_DATABASE_URL;
const pgTestOptions = testDatabaseUrl ? {} : { skip: 'Set TEST_DATABASE_URL to run PostgreSQL integration tests' };

test('postgres store works against the schema SQL', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await resetSchema(pool);

  const store = new PostgresWordStore({ pool });
  const first = await store.insertWord(wordInput({ topics: ['work', 'people'] }));
  const second = await store.insertWord(wordInput({ term: ' reliable ' }));
  const recent = await store.recentWords({ targetLanguage: 'en', limit: 1000 });
  const sync = await store.syncStudyEvents({
    deviceId: 'device_pg',
    events: [
      {
        client_event_id: 'evt_pg_1',
        server_word_id: first.word.id,
        rating: 'easy',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  });
  const retry = await store.syncStudyEvents({
    deviceId: 'device_pg',
    events: [
      {
        client_event_id: 'evt_pg_1',
        server_word_id: first.word.id,
        rating: 'easy',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  });

  assert.equal(first.inserted, true);
  assert.equal(second.inserted, false);
  assert.deepEqual(first.word.topics, ['work', 'people']);
  assert.equal(recent.length, 1);
  assert.deepEqual(sync.accepted_event_ids, ['evt_pg_1']);
  assert.deepEqual(retry.accepted_event_ids, []);
  assert.deepEqual(retry.duplicates, ['evt_pg_1']);
  assert.equal(sync.proficiency.level, 'A1');
});

test('API routes work with postgres store when a test database is available', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await resetSchema(pool);

  const store = new PostgresWordStore({ pool });
  await store.insertWord(wordInput({ id: 'word_api_pg' }));
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
  const batch = await fetchJson(`${baseUrl}/v1/learning/cards`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_api_pg',
      target_language: 'en',
      limit: 10,
      card_mode: 'new'
    })
  });
  assert.equal(batch.items.length, 1);

  const sync = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_api_pg',
      events: [
        {
          client_event_id: 'evt_api_pg_1',
          server_word_id: batch.items[0].server_word_id,
          rating: 'easy',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });

  assert.deepEqual(sync.accepted_event_ids, ['evt_api_pg_1']);
  assert.equal(sync.proficiency.level, 'A1');
});

test('postgres SRS: late offline events replay in order, states page by cursor, misses drop the level', pgTestOptions, async (t) => {
  const pool = new pg.Pool({ connectionString: testDatabaseUrl });
  t.after(async () => pool.end());
  await resetSchema(pool);
  const store = new PostgresWordStore({ pool });
  const { word } = await store.insertWord(wordInput({ term: 'resilient' }));
  const other = (await store.insertWord(wordInput({ term: 'diligent' }))).word;
  const event = (id, rating, occurredAt, wordId = word.id) => ({
    client_event_id: id,
    server_word_id: wordId,
    rating,
    occurred_at: occurredAt
  });

  // The newer rating arrives first; the older offline one arrives later and must not win.
  await store.syncStudyEvents({ deviceId: 'phone', events: [event('b', 'too_hard', '2026-01-03T08:00:00.000Z')] });
  await store.syncStudyEvents({ deviceId: 'phone', events: [event('a', 'easy', '2026-01-01T08:00:00+00:00')] });
  const state = await store.wordStateFor({ deviceId: 'phone', wordId: word.id });
  assert.equal(state.last_rating, 'too_hard');
  assert.equal(state.status, 'learning');
  assert.equal(state.lapses, 1);
  assert.equal(state.review_count, 2);

  await store.syncStudyEvents({ deviceId: 'phone', events: [event('c', 'easy', '2026-01-02T08:00:00.000Z', other.id)] });
  const firstPage = await store.listWordStatesSince({ deviceId: 'any', language: 'en', limit: 1 });
  assert.equal(firstPage.length, 0, 'anonymous states belong to their device');
  const page = await store.listWordStatesSince({ deviceId: 'phone', language: 'en', limit: 10 });
  assert.deepEqual(page.map((row) => row.word.term), ['resilient', 'diligent']);
  const last = page.at(-1).state;
  const after = await store.listWordStatesSince({
    deviceId: 'phone',
    language: 'en',
    cursor: { updatedAt: last.updated_at, id: last.id },
    limit: 10
  });
  assert.deepEqual(after, []);

  assert.equal(await store.rebuildWordStates(), 2);
  assert.equal((await store.wordStateFor({ deviceId: 'phone', wordId: word.id })).lapses, 1);

  // One offline batch of ratings: climbs to A2, then 6 misses in 10 drop it back exactly once.
  const ratings = [...Array(5).fill('too_easy'), ...'mxmxmxmxmmm'.split('').map((c) => (c === 'm' ? 'too_hard' : 'easy'))];
  const batch = await store.syncStudyEvents({
    deviceId: 'kid',
    events: ratings.map((rating, index) =>
      event(`k${index}`, rating, new Date(Date.UTC(2026, 1, 1, 8, 0, index)).toISOString())
    )
  });
  assert.equal(batch.accepted_event_ids.length, ratings.length);
  assert.equal(batch.proficiency.level, 'A1');
  const proficiency = await pool.query(`SELECT level, level_changed_at FROM user_proficiency WHERE device_id = 'kid'`);
  assert.equal(proficiency.rows[0].level, 'A1');
  assert.ok(proficiency.rows[0].level_changed_at);
});

async function resetSchema(pool) {
  await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
  await migrateDatabase({ pool });
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

function wordInput(overrides = {}) {
  return {
    term: 'reliable',
    language: 'en',
    meaning_vi: 'dang tin cay',
    part_of_speech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamese_pronunciation: 'ri-lai-uh-bol',
    example: 'She is a reliable teammate.',
    example_vi: 'Co ay la mot dong doi dang tin cay.',
    difficulty: 'B1',
    topics: ['work'],
    ...overrides
  };
}
