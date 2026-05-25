import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import pg from 'pg';

import { createApp } from '../src/app.js';
import { initializeDatabaseSchema } from '../src/database.js';
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
  assert.deepEqual(retry.accepted_event_ids, ['evt_pg_1']);
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

async function resetSchema(pool) {
  await pool.query(
    'DROP TABLE IF EXISTS shadowing_video_entries, shadowing_video_segments, shadowing_videos, vocabulary_review_items, article_terms, word_senses, terms, article_processing_jobs, articles, user_cached_words, user_word_states, user_proficiency, study_events, words CASCADE'
  );
  await initializeDatabaseSchema({ pool });
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
