import assert from 'node:assert/strict';
import test from 'node:test';

import { PostgresWordStore } from '../src/postgres_word_store.js';
import { DuplicateUserError } from '../src/user_identity.js';

test('postgres store persists words, parses topics, and prevents duplicates', async () => {
  const store = new PostgresWordStore({ pool: new FakePool() });

  const first = await store.insertWord(wordInput({ term: 'Reliable', topics: ['work', 'people'] }));
  const second = await store.insertWord(wordInput({ term: ' reliable ', topics: ['duplicate'] }));
  const batch = await store.learningCards({
    deviceId: 'anonymous_pg_words',
    targetLanguage: 'en',
    limit: 10
  });

  assert.equal(first.inserted, true);
  assert.equal(second.inserted, false);
  assert.equal(first.word.id, second.word.id);
  assert.deepEqual(first.word.topics, ['work', 'people']);
  assert.deepEqual(batch.items.map((card) => card.word.id), [first.word.id]);
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
        rating: 'easy',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  };

  const first = await store.syncStudyEvents(payload);
  const second = await store.syncStudyEvents(payload);

  assert.deepEqual(first.accepted_event_ids, ['evt_1']);
  assert.deepEqual(second.accepted_event_ids, ['evt_1']);
  assert.equal(pool.studyEvents.size, 1);
  assert.equal(first.proficiency.level, 'A1');
});

test('postgres store returns current proficiency for an empty study-event batch', async () => {
  const store = new PostgresWordStore({ pool: new FakePool() });

  const result = await store.syncStudyEvents({
    deviceId: 'device_empty_pg_sync',
    events: []
  });

  assert.deepEqual(result.accepted_event_ids, []);
  assert.deepEqual(result.rejected_events, []);
  assert.equal(result.proficiency.level, 'A1');
});

test('postgres store returns current proficiency when all study events are rejected', async () => {
  const pool = new FakePool();
  const store = new PostgresWordStore({ pool });

  const result = await store.syncStudyEvents({
    deviceId: 'device_rejected_pg_sync',
    events: [
      {
        client_event_id: 'evt_rejected_pg',
        server_word_id: 'word_1',
        rating: 'remembered',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  });

  assert.deepEqual(result.accepted_event_ids, []);
  assert.deepEqual(result.rejected_events, [
    {
      client_event_id: 'evt_rejected_pg',
      reason: 'invalid_rating'
    }
  ]);
  assert.equal(result.proficiency.level, 'A1');
  assert.equal(pool.studyEvents.size, 0);
});

test('postgres store excludes active cache claims when loading learning cards', async () => {
  const store = new PostgresWordStore({ pool: new FakePool() });

  const first = await store.insertWord(
    wordInput({ id: 'word_1', term: 'accomplish', created_at: '2026-05-04T15:10:22.234Z' })
  );
  const second = await store.insertWord(
    wordInput({ id: 'word_2', term: 'expand', created_at: '2026-05-04T15:11:22.234Z' })
  );

  await store.addCachedWordIds({
    deviceId: 'anonymous_pg_cache',
    wordIds: [second.word.id],
    observedAt: '2026-05-05T00:00:00.000Z'
  });

  const batch = await store.learningCards({
    deviceId: 'anonymous_pg_cache',
    targetLanguage: 'en',
    limit: 1
  });

  assert.deepEqual(batch.items.map((card) => card.word.id), [first.word.id]);
});

test('postgres store claims cached words when cache unique indexes are missing', async () => {
  const pool = new MissingCacheConflictTargetPool();
  const store = new PostgresWordStore({ pool });
  const word = await store.insertWord(wordInput({ id: 'word_cache_index_gap' }));

  await store.addCachedWordIds({
    deviceId: 'anonymous_index_gap',
    wordIds: [word.word.id],
    observedAt: '2026-05-05T00:00:00.000Z'
  });
  await store.addCachedWordIds({
    deviceId: 'device_index_gap',
    userId: 'user_index_gap',
    wordIds: [word.word.id],
    observedAt: '2026-05-05T00:01:00.000Z'
  });

  assert.equal(pool.userCachedWords.size, 2);
});

test('postgres store levels up after five consecutive too_easy ratings', async () => {
  const store = new PostgresWordStore({ pool: new FakePool() });

  for (let index = 0; index < 5; index += 1) {
    const result = await store.recordStudyEvent({
      deviceId: 'device_2',
      event: {
        client_event_id: `evt_level_${index + 1}`,
        server_word_id: 'word_1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:31:0${index}.000Z`
      }
    });

    if (index === 4) {
      assert.equal(result.proficiency.level, 'A2');
      assert.equal(result.proficiency.level_changed, true);
    }
  }
});

test('postgres store initializes proficiency with explicit anonymous and signed-in ownership', async () => {
  const pool = new FakePool();
  const store = new PostgresWordStore({ pool });

  const anonymous = await store.getOrInitializeProficiency({
    deviceId: 'device_profile',
    language: 'en'
  });
  const anonymousRetry = await store.getOrInitializeProficiency({
    deviceId: 'device_profile',
    language: 'en'
  });
  const signedIn = await store.getOrInitializeProficiency({
    deviceId: 'device_profile',
    userId: 'user_profile',
    language: 'en'
  });
  const signedInRetry = await store.getOrInitializeProficiency({
    deviceId: 'second_device_profile',
    userId: 'user_profile',
    language: 'en'
  });

  assert.equal(anonymous.user_id, null);
  assert.equal(anonymous.device_id, 'device_profile');
  assert.equal(anonymousRetry.id, anonymous.id);
  assert.equal(signedIn.user_id, 'user_profile');
  assert.equal(signedIn.device_id, 'device_profile');
  assert.equal(signedInRetry.id, signedIn.id);
  assert.equal(pool.userProficiencies.size, 2);
});

test('postgres store registers users, resolves sessions, revokes sessions, and excludes learned words by user', async () => {
  const store = new PostgresWordStore({ pool: new FakePool() });
  const newest = await store.insertWord(
    wordInput({ id: 'word_identity_new', term: 'newest', created_at: '2026-05-04T15:12:22.234Z' })
  );
  const older = await store.insertWord(
    wordInput({ id: 'word_identity_old', term: 'older', created_at: '2026-05-04T15:11:22.234Z' })
  );

  const registered = await store.registerUser({
    identifier: 'Learner@Example.com',
    password: 'correct-password',
    displayName: 'Learner',
    deviceId: 'device_identity'
  });

  assert.equal(registered.user.identifier, 'learner@example.com');
  assert.ok(registered.sessionToken);
  await assert.rejects(
    () => store.registerUser({ identifier: 'learner@example.com', password: 'correct-password' }),
    DuplicateUserError
  );

  const signedIn = await store.createUserSession({
    identifier: 'learner@example.com',
    password: 'correct-password',
    deviceId: 'device_identity'
  });
  const resolved = await store.resolveUserSession({ sessionToken: signedIn.sessionToken });

  assert.equal(signedIn.user.id, registered.user.id);
  assert.equal(resolved.user.id, registered.user.id);

  await store.recordStudyEvent({
    deviceId: 'device_identity',
    userId: registered.user.id,
    event: {
      client_event_id: 'evt_identity_1',
      server_word_id: newest.word.id,
      rating: 'easy',
      occurred_at: '2026-05-04T10:40:00.000Z'
    }
  });

  const batch = await store.learningCards({
    targetLanguage: 'en',
    limit: 1,
    deviceId: 'device_identity',
    userId: registered.user.id
  });

  assert.deepEqual(batch.items.map((card) => card.word.id), [older.word.id]);

  const revoked = await store.revokeUserSession({ sessionToken: signedIn.sessionToken });
  const afterRevoke = await store.resolveUserSession({ sessionToken: signedIn.sessionToken });

  assert.equal(revoked.revoked, true);
  assert.equal(afterRevoke, null);
});

test('postgres store maps duplicate user insert races to duplicate user errors', async () => {
  const pool = new FakePool();
  const store = new PostgresWordStore({ pool });
  pool.nextUserInsertError = Object.assign(new Error('duplicate key value violates unique constraint'), {
    code: '23505'
  });

  await assert.rejects(
    () =>
      store.registerUser({
        identifier: 'race@example.com',
        password: 'correct-password'
      }),
    DuplicateUserError
  );
});

test('postgres store does not mask non-duplicate user insert errors', async () => {
  const pool = new FakePool();
  const store = new PostgresWordStore({ pool });
  const persistenceError = Object.assign(new Error('database is unavailable'), {
    code: '57P01'
  });
  pool.nextUserInsertError = persistenceError;

  await assert.rejects(
    () =>
      store.registerUser({
        identifier: 'outage@example.com',
        password: 'correct-password'
      }),
    persistenceError
  );
});

class FakePool {
  constructor() {
    this.words = new Map();
    this.studyEvents = new Map();
    this.userProficiencies = new Map();
    this.userWordStates = new Map();
    this.userCachedWords = new Map();
    this.users = new Map();
    this.sessions = new Map();
  }

  async query(sql, params = []) {
    const normalizedSql = sql.replace(/\s+/g, ' ').trim();

    if (normalizedSql === 'BEGIN' || normalizedSql === 'COMMIT' || normalizedSql === 'ROLLBACK') {
      return { rows: [] };
    }

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
      normalizedSql.includes('ORDER BY updated_at DESC')
    ) {
      return {
        rows: [...this.words.values()]
          .filter((word) => word.language === params[0])
          .sort((a, b) => b.updated_at.localeCompare(a.updated_at))
          .slice(0, params[1])
      };
    }

    if (normalizedSql === 'SELECT * FROM words WHERE language = $1') {
      return {
        rows: [...this.words.values()].filter((word) => word.language === params[0])
      };
    }

    if (normalizedSql.startsWith('SELECT id FROM words WHERE id = ANY')) {
      return {
        rows: params[0]
          .filter((wordId) => this.words.has(wordId))
          .map((id) => ({ id }))
      };
    }

    if (normalizedSql.startsWith('DELETE FROM user_cached_words')) {
      const ownerKind = normalizedSql.includes('user_id = $1') ? 'user' : 'device';
      for (const [key, row] of this.userCachedWords.entries()) {
        if (
          (ownerKind === 'user' && row.user_id === params[0]) ||
          (ownerKind === 'device' && row.device_id === params[0] && row.user_id === null)
        ) {
          this.userCachedWords.delete(key);
        }
      }
      return { rows: [] };
    }

    if (normalizedSql.startsWith('UPDATE user_cached_words')) {
      const ownerKind = normalizedSql.includes('WHERE user_id = $2') ? 'user' : 'device';
      const key = ownerKind === 'user'
        ? `user:${params[1]}:${params[2]}`
        : `device:${params[0]}:${params[2]}`;
      const existing = this.userCachedWords.get(key);
      if (!existing) {
        return { rows: [], rowCount: 0 };
      }
      existing.device_id = params[0];
      existing.observed_at = params[3];
      existing.updated_at = params[4];
      return { rows: [], rowCount: 1 };
    }

    if (normalizedSql.startsWith('INSERT INTO user_cached_words')) {
      const row = cachedWordRowFromParams(params);
      const key = row.user_id
        ? `user:${row.user_id}:${row.word_id}`
        : `device:${row.device_id}:${row.word_id}`;
      this.userCachedWords.set(key, row);
      return { rows: [] };
    }

    if (normalizedSql.startsWith('SELECT word_id FROM user_cached_words')) {
      const ownerKind = normalizedSql.includes('WHERE user_id = $1') ? 'user' : 'device';
      return {
        rows: [...this.userCachedWords.values()]
          .filter((row) =>
            ownerKind === 'user'
              ? row.user_id === params[0]
              : row.device_id === params[0] && row.user_id === null
          )
          .map((row) => ({ word_id: row.word_id }))
      };
    }

    if (normalizedSql.startsWith('INSERT INTO study_events')) {
      const row = studyEventRowFromParams(params);
      if (!this.studyEvents.has(row.client_event_id)) {
        this.studyEvents.set(row.client_event_id, row);
        return { rows: [row] };
      }
      return { rows: [] };
    }

    if (normalizedSql.startsWith('INSERT INTO user_word_states')) {
      const row = wordStateRowFromParams(params);
      const key = row.user_id ? `user:${row.user_id}:${row.word_id}` : `device:${row.device_id}:${row.word_id}`;
      const existing = this.userWordStates.get(key);
      if (existing) {
        Object.assign(existing, {
          device_id: row.device_id,
          language: row.language,
          status: row.status,
          last_rating: row.last_rating,
          last_studied_at: row.last_studied_at,
          next_review_at: row.next_review_at,
          review_count: existing.review_count + 1,
          updated_at: row.updated_at
        });
        return { rows: [] };
      }
      this.userWordStates.set(key, row);
      return { rows: [] };
    }

    if (
      normalizedSql.startsWith('SELECT * FROM user_word_states') &&
      normalizedSql.includes('(user_id = $1 OR (device_id = $2 AND user_id IS NULL))')
    ) {
      return {
        rows: [...this.userWordStates.values()]
          .filter((state) => state.language === params[2])
          .filter((state) => state.user_id === params[0] || (state.device_id === params[1] && state.user_id === null))
      };
    }

    if (normalizedSql.startsWith('SELECT * FROM user_word_states')) {
      const ownerKind = normalizedSql.includes('WHERE user_id = $1') ? 'user' : 'device';
      return {
        rows: [...this.userWordStates.values()]
          .filter((state) => state.language === params[1])
          .filter((state) =>
            ownerKind === 'user'
              ? state.user_id === params[0]
              : state.device_id === params[0] && state.user_id === null
          )
      };
    }

    if (
      normalizedSql.startsWith('SELECT * FROM study_events') &&
      normalizedSql.includes('ORDER BY occurred_at DESC')
    ) {
      const ownerField = normalizedSql.includes('WHERE user_id = $1') ? 'user_id' : 'device_id';
      return {
        rows: [...this.studyEvents.values()]
          .filter((event) => event[ownerField] === params[0])
          .sort((left, right) => {
            const occurred = right.occurred_at.localeCompare(left.occurred_at);
            return occurred !== 0 ? occurred : right.received_at.localeCompare(left.received_at);
          })
          .slice(0, 10)
      };
    }

    if (normalizedSql.startsWith('SELECT * FROM user_proficiency')) {
      const key = proficiencyKeyFromQuery(normalizedSql, params);
      const row = this.userProficiencies.get(key);
      return { rows: row ? [row] : [] };
    }

    if (normalizedSql.startsWith('INSERT INTO user_proficiency')) {
      const row = proficiencyRowFromParams(params);
      const key = proficiencyKey(row);
      const existing = this.userProficiencies.get(key);
      if (existing) {
        return { rows: [existing] };
      }
      this.userProficiencies.set(key, row);
      return { rows: [row] };
    }

    if (normalizedSql.startsWith('UPDATE user_proficiency')) {
      const key = normalizedSql.includes('WHERE user_id = $1')
        ? `user:${params[0]}:${params[1]}`
        : `device:${params[0]}:${params[1]}`;
      const existing = this.userProficiencies.get(key);
      existing.level = params[2];
      existing.updated_at = params[3];
      return { rows: [existing] };
    }

    if (normalizedSql.startsWith('SELECT * FROM users')) {
      const row = [...this.users.values()].find((user) => user.identifier === params[0]);
      return { rows: row ? [row] : [] };
    }

    if (normalizedSql.startsWith('INSERT INTO users')) {
      if (this.nextUserInsertError) {
        const error = this.nextUserInsertError;
        this.nextUserInsertError = null;
        throw error;
      }
      const row = userRowFromParams(params);
      this.users.set(row.id, row);
      return { rows: [row] };
    }

    if (normalizedSql.startsWith('INSERT INTO user_sessions')) {
      const row = sessionRowFromParams(params);
      this.sessions.set(row.token_hash, row);
      return { rows: [row] };
    }

    if (normalizedSql.startsWith('SELECT user_sessions.*')) {
      const session = this.sessions.get(params[0]);
      if (!session || session.revoked_at) {
        return { rows: [] };
      }
      const user = this.users.get(session.user_id);
      return {
        rows: [
          {
            ...session,
            identifier: user.identifier,
            display_name: user.display_name
          }
        ]
      };
    }

    if (normalizedSql.startsWith('UPDATE user_sessions')) {
      const session = this.sessions.get(params[0]);
      if (!session || session.revoked_at) {
        return { rows: [] };
      }
      session.revoked_at = params[1];
      return { rows: [session] };
    }

    throw new Error(`Unexpected SQL: ${normalizedSql}`);
  }

}

class MissingCacheConflictTargetPool extends FakePool {
  async query(sql, params = []) {
    const normalizedSql = sql.replace(/\s+/g, ' ').trim();
    if (
      normalizedSql.startsWith('INSERT INTO user_cached_words') &&
      normalizedSql.includes('ON CONFLICT (')
    ) {
      throw new Error('there is no unique or exclusion constraint matching the ON CONFLICT specification');
    }
    return super.query(sql, params);
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

function wordStateRowFromParams(params) {
  const [
    id,
    user_id,
    device_id,
    word_id,
    language,
    status,
    last_rating,
    last_studied_at,
    next_review_at,
    updated_at
  ] = params;
  return {
    id,
    user_id,
    device_id,
    word_id,
    language,
    status,
    last_rating,
    last_studied_at,
    next_review_at,
    review_count: 1,
    updated_at
  };
}

function cachedWordRowFromParams(params) {
  const [device_id, user_id, word_id, observed_at, updated_at] = params;
  return {
    device_id,
    user_id,
    word_id,
    observed_at,
    updated_at
  };
}

function proficiencyRowFromParams(params) {
  const [id, user_id, device_id, language, level, created_at, updated_at] = params;
  return { id, user_id, device_id, language, level, created_at, updated_at };
}

function userRowFromParams(params) {
  const [id, identifier, display_name, password_hash, created_at, updated_at] = params;
  return { id, identifier, display_name, password_hash, created_at, updated_at };
}

function sessionRowFromParams(params) {
  const [id, user_id, token_hash, device_id, created_at] = params;
  return { id, user_id, token_hash, device_id, created_at, revoked_at: null };
}

function proficiencyKey(row) {
  return row.user_id
    ? `user:${row.user_id}:${row.language}`
    : `device:${row.device_id}:${row.language}`;
}

function proficiencyKeyFromQuery(normalizedSql, params) {
  return normalizedSql.includes('WHERE user_id = $1')
    ? `user:${params[0]}:${params[1]}`
    : `device:${params[0]}:${params[1]}`;
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
