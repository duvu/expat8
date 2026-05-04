import assert from 'node:assert/strict';
import test from 'node:test';

import { PostgresWordStore } from '../src/postgres_word_store.js';

test('postgres store persists words, parses topics, and prevents duplicates', async () => {
  const store = new PostgresWordStore({ pool: new FakePool() });

  const first = await store.insertWord(wordInput({ term: 'Reliable', topics: ['work', 'people'] }));
  const second = await store.insertWord(wordInput({ term: ' reliable ', topics: ['duplicate'] }));
  const words = await store.findNewWords({ targetLanguage: 'en', limit: 10 });

  assert.equal(first.inserted, true);
  assert.equal(second.inserted, false);
  assert.equal(first.word.id, second.word.id);
  assert.deepEqual(first.word.topics, ['work', 'people']);
  assert.deepEqual(words.map((word) => word.id), [first.word.id]);
});

test('postgres store syncs study events idempotently', async () => {
  const pool = new FakePool();
  const store = new PostgresWordStore({ pool });
  const word = await store.insertWord(wordInput({ id: 'word_1' }));
  const payload = {
    deviceId: 'device_1',
    events: [
      {
        client_event_id: 'evt_1',
        server_word_id: word.word.id,
        local_word_id: 'local_1',
        rating: 'remembered',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  };

  const first = await store.syncStudyEvents(payload);
  const second = await store.syncStudyEvents(payload);

  assert.deepEqual(first.accepted_event_ids, ['evt_1']);
  assert.deepEqual(second.accepted_event_ids, ['evt_1']);
  assert.equal(pool.studyEvents.size, 1);
});

test('postgres store excludes the current word when loading new words', async () => {
  const store = new PostgresWordStore({ pool: new FakePool() });

  const first = await store.insertWord(
    wordInput({ id: 'word_1', term: 'accomplish', created_at: '2026-05-04T15:10:22.234Z' })
  );
  const second = await store.insertWord(
    wordInput({ id: 'word_2', term: 'expand', created_at: '2026-05-04T15:11:22.234Z' })
  );

  const words = await store.findNewWords({
    targetLanguage: 'en',
    limit: 1,
    excludeWordIds: [second.word.id]
  });

  assert.deepEqual(words.map((word) => word.id), [first.word.id]);
});

class FakePool {
  constructor() {
    this.words = new Map();
    this.studyEvents = new Map();
  }

  async query(sql, params = []) {
    const normalizedSql = sql.replace(/\s+/g, ' ').trim();

    if (normalizedSql.startsWith('INSERT INTO words')) {
      const row = wordRowFromParams(params);
      const existing = [...this.words.values()].find(
        (word) => word.language === row.language && word.normalized_term === row.normalized_term
      );
      if (existing) {
        return { rows: [] };
      }
      this.words.set(row.id, row);
      return { rows: [row] };
    }

    if (
      normalizedSql.startsWith('SELECT * FROM words') &&
      normalizedSql.includes('normalized_term = $2')
    ) {
      return {
        rows: [...this.words.values()].filter(
          (word) => word.language === params[0] && word.normalized_term === params[1]
        )
      };
    }

    if (
      normalizedSql.startsWith('SELECT * FROM words') &&
      normalizedSql.includes('ORDER BY created_at DESC')
    ) {
      const excludeWordIds = Array.isArray(params[1]) ? params[1] : [];
      const limit = Array.isArray(params[1]) ? params[2] : params[1];
      return {
        rows: [...this.words.values()]
          .filter((word) => word.language === params[0])
          .filter((word) => !excludeWordIds.includes(word.id))
          .sort((a, b) => b.created_at.localeCompare(a.created_at))
          .slice(0, limit)
      };
    }

    if (
      normalizedSql.startsWith('SELECT * FROM words') &&
      normalizedSql.includes('ORDER BY updated_at DESC')
    ) {
      return {
        rows: [...this.words.values()]
          .filter((word) => word.language === params[0])
          .sort((a, b) => b.updated_at.localeCompare(a.updated_at))
          .slice(0, params[1])
      };
    }

    if (normalizedSql.startsWith('INSERT INTO study_events')) {
      const row = studyEventRowFromParams(params);
      if (!this.studyEvents.has(row.client_event_id)) {
        this.studyEvents.set(row.client_event_id, row);
      }
      return { rows: [] };
    }

    throw new Error(`Unexpected SQL: ${normalizedSql}`);
  }
}

function wordRowFromParams(params) {
  const [
    id,
    term,
    normalized_term,
    language,
    meaning_vi,
    part_of_speech,
    ipa,
    vietnamese_pronunciation,
    example,
    example_vi,
    difficulty,
    topics_json,
    generation_source,
    created_at,
    updated_at
  ] = params;
  return {
    id,
    term,
    normalized_term,
    language,
    meaning_vi,
    part_of_speech,
    ipa,
    vietnamese_pronunciation,
    example,
    example_vi,
    difficulty,
    topics_json,
    generation_source,
    created_at,
    updated_at
  };
}

function studyEventRowFromParams(params) {
  const [
    id,
    client_event_id,
    device_id,
    user_id,
    word_id,
    local_word_id,
    rating,
    occurred_at,
    received_at
  ] = params;
  return {
    id,
    client_event_id,
    device_id,
    user_id,
    word_id,
    local_word_id,
    rating,
    occurred_at,
    received_at
  };
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
