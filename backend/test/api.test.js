import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('serves unified learning cards, recent words, and idempotent sync', async (t) => {
  const store = new WordStore({ seed: false });
  for (let index = 0; index < 120; index += 1) {
    store.insertWord(wordInput({
      id: `word_batch_${index}`,
      term: `batch ${index}`,
      created_at: `2026-05-04T10:${(index % 60).toString().padStart(2, '0')}:00.000Z`,
      updated_at: `2026-05-04T10:${(index % 60).toString().padStart(2, '0')}:00.000Z`
    }));
  }
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

  const batch = await postLearningCards(baseUrl, {
    device_id: 'anonymous_device_1',
    target_language: 'en',
    limit: 100,
    card_mode: 'new'
  });
  assert.equal(batch.items.length, 100);
  assert.deepEqual(batch.target_mix, { new: 15, review: 85 });
  assert.deepEqual(batch.actual_mix, { new: 100, review: 0 });
  assert.ok(batch.items.every((item) => item.language === 'en'));

  const excluded = await fetch(`${baseUrl}/v1/learning/cards`, signedFetchOptions(`${baseUrl}/v1/learning/cards`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'anonymous_device_1',
      target_language: 'en',
      limit: 10,
      exclude_server_word_id: batch.items[0].server_word_id
    })
  }));
  assert.equal(excluded.status, 400);

  const secondBatch = await postLearningCards(baseUrl, {
    device_id: 'anonymous_device_1',
    target_language: 'en',
    limit: 100,
    card_mode: 'new'
  });
  assert.equal(secondBatch.items.length, 20);
  const firstIds = new Set(batch.items.map((item) => item.server_word_id));
  assert.ok(secondBatch.items.every((item) => !firstIds.has(item.server_word_id)));

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
          server_word_id: batch.items[0].server_word_id,
          local_word_id: 'local_1',
          rating: 'easy',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });
  assert.deepEqual(sync.accepted_event_ids, ['evt_1']);
  assert.equal(sync.proficiency.level, 'A1');

  const retry = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_1',
      events: [
        {
          client_event_id: 'evt_1',
          server_word_id: batch.items[0].server_word_id,
          local_word_id: 'local_1',
          rating: 'easy',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });
  assert.deepEqual(retry.accepted_event_ids, []);
  assert.deepEqual(retry.duplicates, ['evt_1']);
  assert.equal(store.studyEventsByClientId.size, 1);

  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=device_1&language=en`);
  assert.equal(proficiency.level, 'A1');
});

test('syncs speaking events separately from rating study events', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_speaking', term: 'speaking' }));
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
  const sync = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_speaking',
      events: [
        {
          client_event_id: 'evt_rating_for_speaking_test',
          server_word_id: 'word_speaking',
          rating: 'easy',
          occurred_at: '2026-05-04T10:00:00.000Z'
        },
        {
          client_event_id: 'evt_speaking_recorded',
          event_type: 'speaking_recorded',
          occurred_at: '2026-05-04T10:01:00.000Z',
          language: 'en',
          speaking: {
            attempt_id: 'attempt_1',
            prompt_id: 'prompt_1',
            server_word_id: 'word_speaking',
            duration_ms: 4300,
            retry_count: 0,
            self_rating: null
          }
        },
        {
          client_event_id: 'evt_speaking_clear',
          event_type: 'speaking_self_rated_clear',
          occurred_at: '2026-05-04T10:01:05.000Z',
          language: 'en',
          speaking: {
            attempt_id: 'attempt_1',
            prompt_id: 'prompt_1',
            server_word_id: 'word_speaking',
            duration_ms: 4300,
            retry_count: 0,
            self_rating: 'clear'
          }
        },
        {
          client_event_id: 'evt_speaking_unknown',
          event_type: 'speaking_magic_score',
          occurred_at: '2026-05-04T10:01:10.000Z',
          speaking: { attempt_id: 'attempt_invalid' }
        },
        {
          client_event_id: 'evt_speaking_audio_path',
          event_type: 'speaking_recorded',
          occurred_at: '2026-05-04T10:01:15.000Z',
          speaking: {
            attempt_id: 'attempt_2',
            local_audio_path: '/tmp/private-recording.m4a'
          }
        }
      ]
    })
  });

  assert.deepEqual(sync.accepted_event_ids, [
    'evt_rating_for_speaking_test',
    'evt_speaking_recorded',
    'evt_speaking_clear'
  ]);
  assert.equal(sync.rejected_events.length, 2);
  assert.deepEqual(
    sync.rejected_events.map((event) => event.reason).sort(),
    ['forbidden_audio_field', 'invalid_speaking_event_type']
  );
  assert.equal(store.studyEventsByClientId.size, 1);
  assert.equal(store.speakingEventsByKey.size, 2);
  assert.equal(sync.proficiency.level, 'A1');

  const retry = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_speaking',
      events: [
        {
          client_event_id: 'evt_speaking_recorded',
          event_type: 'speaking_recorded',
          occurred_at: '2026-05-04T10:01:00.000Z',
          language: 'en',
          speaking: {
            attempt_id: 'attempt_1',
            duration_ms: 4300,
            retry_count: 0
          }
        }
      ]
    })
  });
  assert.deepEqual(retry.accepted_event_ids, []);
  assert.deepEqual(retry.duplicates, ['evt_speaking_recorded']);

  const summary = await fetchJson(`${baseUrl}/v1/speaking/summary?device_id=device_speaking&language=en&week_start=2026-05-04`);
  assert.equal(summary.spoken_sentence_count, 1);
  assert.equal(summary.recording_count, 1);
  assert.equal(summary.retry_count, 0);
  assert.equal(summary.approximate_duration_ms, 4300);
  assert.deepEqual(summary.self_rating_counts, {
    clear: 1,
    hesitated: 0,
    could_not_say: 0
  });
});

test('rejects unsupported learning card modes before store selection', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_card_mode', term: 'mode' }));
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
  const url = `${baseUrl}/v1/learning/cards`;
  const response = await fetch(url, signedFetchOptions(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'anonymous_card_mode',
      target_language: 'en',
      limit: 10,
      card_mode: 'review'
    })
  }));

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'bad_request' });
});

test('recent words only honor documented bootstrap query parameters', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({
    id: 'word_recent_en',
    term: 'recent en',
    language: 'en',
    updated_at: '2026-05-04T10:00:00.000Z'
  }));
  store.insertWord(wordInput({
    id: 'word_recent_ja',
    term: 'recent ja',
    language: 'ja',
    updated_at: '2026-05-04T11:00:00.000Z'
  }));
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
  const recent = await fetchJson(
    `${baseUrl}/v1/words/recent?limit=1&target_language=en&source_language=vi&device_id=ignored&exclude_server_word_id=word_recent_en`
  );

  assert.deepEqual(recent.items.map((item) => item.server_word_id), ['word_recent_en']);
});

test('does not call AI generation inline when word pool is empty', async (t) => {
  const store = new WordStore({ seed: false });
  const generationService = {
    calls: 0,
    async generateAndStore({ targetLanguage, limit }) {
      this.calls += 1;
      return [];
    }
  };
  const server = http.createServer(
    createApp({
      store,
      generationService,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const next = await postLearningCards(baseUrl, {
    device_id: 'anonymous_empty',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });

  assert.equal(generationService.calls, 0);
  assert.equal(next.items.length, 0);
});

test('serves backend-selected learning cards as ten new cards and records active claims', async (t) => {
  const store = new WordStore({ seed: false });
  for (let index = 0; index < 12; index += 1) {
    store.insertWord(wordInput({
      id: `new_${index}`,
      term: `new ${index}`,
      created_at: `2026-05-02T00:${index.toString().padStart(2, '0')}:00.000Z`,
      updated_at: `2026-05-02T00:${index.toString().padStart(2, '0')}:00.000Z`
    }));
  }
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
  const batch = await postLearningCards(baseUrl, {
    device_id: 'anonymous_mix',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });

  assert.deepEqual(batch.target_mix, { new: 2, review: 8 });
  assert.deepEqual(batch.actual_mix, { new: 10, review: 0 });
  assert.equal(batch.items.filter((item) => item.card_type === 'new').length, 10);
  assert.ok(batch.items.every((item) => typeof item.selection_reason === 'string'));

  const nextBatch = await postLearningCards(baseUrl, {
    device_id: 'anonymous_mix',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  assert.equal(nextBatch.items.length, 2);
});

test('replaces cache inventory, filters unknown ids, and excludes cached words from new-card selection', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'cached_word', term: 'cached' }));
  store.insertWord(wordInput({ id: 'available_word', term: 'available' }));
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
  const putUrl = `${baseUrl}/v1/user-word-cache`;
  const cache = await fetchJson(putUrl, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_cache',
      server_word_ids: ['cached_word', 'missing_word'],
      observed_at: '2026-05-05T00:00:00.000Z'
    })
  });

  assert.equal(cache.stored_count, 1);
  assert.deepEqual(cache.unknown_server_word_ids, ['missing_word']);

  const batch = await postLearningCards(baseUrl, {
    device_id: 'device_cache',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  assert.equal(batch.items.length, 1);
  assert.equal(batch.items[0].server_word_id, 'available_word');
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

  const next = await postLearningCards(baseUrl, {
    device_id: 'anonymous_async',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  assert.ok(next.items.length >= 2, `expected at least 2 items, got ${next.items.length}`);

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
          rating: 'easy',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });

  assert.deepEqual(sync.accepted_event_ids, ['evt_async_1']);
});

test('returns proficiency change after five consecutive too_easy ratings', async (t) => {
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
  let result;

  for (let index = 0; index < 5; index += 1) {
    result = await fetchJson(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: 'device_level',
        client_event_id: `evt_level_${index + 1}`,
        word_id: 'word_reliable',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:40:0${index}.000Z`
      })
    });
  }

  assert.equal(result.success, true);
  assert.equal(result.proficiency.level, 'A2');
  assert.equal(result.proficiency.level_changed, true);
  assert.equal(result.proficiency.previous_level, 'A1');
});

test('returns level-down after five consecutive hard ratings', async (t) => {
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

  for (let index = 0; index < 5; index += 1) {
    await fetchJson(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: 'device_hard',
        client_event_id: `evt_hard_up_${index + 1}`,
        word_id: 'word_reliable',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:41:0${index}.000Z`
      })
    });
  }

  let result;
  for (let index = 0; index < 5; index += 1) {
    result = await fetchJson(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: 'device_hard',
        client_event_id: `evt_hard_down_${index + 1}`,
        word_id: 'word_reliable',
        rating: 'hard',
        occurred_at: `2026-05-04T10:42:0${index}.000Z`
      })
    });
  }

  assert.equal(result.proficiency.level, 'A1');
  assert.equal(result.proficiency.level_changed, true);
  assert.equal(result.proficiency.previous_level, 'A2');
});

test('rejects invalid rating on single-event endpoint', async (t) => {
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
  const response = await fetch(
    `${baseUrl}/v1/study-events`,
    signedFetchOptions(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: 'device_invalid',
        client_event_id: 'evt_invalid',
        word_id: 'word_reliable',
        rating: 'remembered',
        occurred_at: '2026-05-04T10:43:00.000Z'
      })
    })
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'invalid_rating' });
});

test('uses device_id to resolve proficiency when learning cards omit explicit level', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord({
    id: 'word_a1',
    term: 'basic',
    language: 'en',
    meaning_vi: 'co ban',
    part_of_speech: 'adjective',
    ipa: '/ˈbeɪ.sɪk/',
    vietnamese_pronunciation: 'bay-sik',
    example: 'This is a basic question.',
    example_vi: 'Day la mot cau hoi co ban.',
    difficulty: 'A1',
    topics: ['study']
  });
  store.insertWord({
    id: 'word_a2',
    term: 'gather',
    language: 'en',
    meaning_vi: 'thu thap',
    part_of_speech: 'verb',
    ipa: '/ˈɡæð.ər/',
    vietnamese_pronunciation: 'ga-der',
    example: 'We gather ideas before the meeting.',
    example_vi: 'Chung toi thu thap y tuong truoc cuoc hop.',
    difficulty: 'A2',
    topics: ['work']
  });
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
  for (let index = 0; index < 5; index += 1) {
    await fetchJson(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: 'device_feed',
        client_event_id: `evt_feed_${index + 1}`,
        word_id: 'word_a1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:44:0${index}.000Z`
      })
    });
  }

  const next = await postLearningCards(baseUrl, {
    device_id: 'device_feed',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });
  assert.equal(next.items[0].server_word_id, 'word_a2');
});

test('does not expose legacy words next route', async (t) => {
  const store = new WordStore({ seed: false });
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
  const response = await fetch(
    `${baseUrl}/v1/words/next?limit=1&target_language=en`,
    signedFetchOptions(`${baseUrl}/v1/words/next?limit=1&target_language=en`)
  );

  assert.equal(response.status, 404);
});

test('registers, signs in, signs out, and associates signed-in learning with user', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord(
    wordInput({
      id: 'word_identity_a',
      term: 'identify',
      difficulty: 'A1',
      created_at: '2026-05-04T16:00:00.000Z',
      updated_at: '2026-05-04T16:00:00.000Z'
    })
  );
  store.insertWord(
    wordInput({
      id: 'word_identity_b',
      term: 'account',
      difficulty: 'A1',
      created_at: '2026-05-04T16:01:00.000Z',
      updated_at: '2026-05-04T16:01:00.000Z'
    })
  );
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
  const registered = await fetchJson(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'learner@example.com',
      password: 'correct horse battery staple',
      display_name: 'Learner One',
      device_id: 'device_identity'
    })
  });

  assert.match(registered.user_id, /^user_/);
  assert.equal(registered.identifier, 'learner@example.com');
  assert.equal(typeof registered.session_token, 'string');

  const duplicate = await fetch(`${baseUrl}/v1/users/register`, signedFetchOptions(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'learner@example.com',
      password: 'another password',
      device_id: 'device_identity'
    })
  }));
  assert.equal(duplicate.status, 409);

  const signedIn = await fetchJson(`${baseUrl}/v1/users/sign-in`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'learner@example.com',
      password: 'correct horse battery staple',
      device_id: 'device_identity'
    })
  });
  assert.equal(signedIn.user_id, registered.user_id);

  const me = await fetchJson(`${baseUrl}/v1/me`, {
    method: 'GET',
    headers: bearerHeaders(signedIn.session_token)
  });
  assert.equal(me.user_id, registered.user_id);
  assert.equal(me.identifier, 'learner@example.com');
  assert.equal(me.display_name, 'Learner One');

  const first = await postLearningCards(baseUrl, {
    device_id: 'device_identity',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  }, {
    authorization: `Bearer ${signedIn.session_token}`
  });
  assert.deepEqual(
    first.items.map((item) => item.server_word_id),
    ['word_identity_b', 'word_identity_a']
  );

  const event = await fetchJson(`${baseUrl}/v1/study-events`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...bearerHeaders(signedIn.session_token)
    },
    body: JSON.stringify({
      device_id: 'device_identity',
      client_event_id: 'evt_identity_1',
      word_id: first.items[0].server_word_id,
      rating: 'easy',
      occurred_at: '2026-05-04T16:00:00.000Z'
    })
  });
  assert.equal(event.success, true);

  const second = await postLearningCards(baseUrl, {
    device_id: 'device_identity',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  }, {
    authorization: `Bearer ${signedIn.session_token}`
  });
  assert.deepEqual(second.items, []);

  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=device_identity&language=en`, {
    headers: bearerHeaders(signedIn.session_token)
  });
  assert.equal(proficiency.user_id, registered.user_id);

  const signOut = await fetchJson(`${baseUrl}/v1/users/sign-out`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...bearerHeaders(signedIn.session_token)
    },
    body: JSON.stringify({})
  });
  assert.equal(signOut.success, true);

  const invalidMe = await fetch(
    `${baseUrl}/v1/me`,
    signedFetchOptions(`${baseUrl}/v1/me`, {
      method: 'GET',
      headers: bearerHeaders(signedIn.session_token)
    })
  );
  assert.equal(invalidMe.status, 401);
  assert.deepEqual(await invalidMe.json(), { error: 'invalid_session' });

  const afterSignOut = await fetch(`${baseUrl}/v1/proficiency?device_id=device_identity&language=en`, signedFetchOptions(`${baseUrl}/v1/proficiency?device_id=device_identity&language=en`, {
    headers: bearerHeaders(signedIn.session_token)
  }));
  assert.equal(afterSignOut.status, 401);
});

test('handles browser CORS preflight while preserving app credential protection', async (t) => {
  const store = new CountingStore();
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig({
        CORS_ALLOWED_ORIGIN: 'http://localhost:8080'
      })
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const registerUrl = `${baseUrl}/v1/users/register`;
  const origin = 'http://localhost:8080';

  const preflight = await fetch(registerUrl, {
    method: 'OPTIONS',
    headers: {
      origin,
      'access-control-request-method': 'POST',
      'access-control-request-headers':
        'content-type,authorization,x-expat8-app-id,x-expat8-timestamp,x-expat8-nonce,x-expat8-content-sha256,x-expat8-signature'
    }
  });

  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), origin);
  assert.match(preflight.headers.get('access-control-allow-methods'), /POST/);
  assert.match(preflight.headers.get('access-control-allow-methods'), /OPTIONS/);
  assert.match(preflight.headers.get('access-control-allow-headers'), /x-expat8-app-id/);
  assert.equal(store.registerUserCalls, 0);

  const unsigned = await fetch(registerUrl, {
    method: 'POST',
    headers: {
      origin,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      identifier: 'cors@example.com',
      password: 'correct horse battery staple',
      device_id: 'device_cors'
    })
  });
  assert.equal(unsigned.status, 400);
  assert.equal(unsigned.headers.get('access-control-allow-origin'), origin);
  assert.deepEqual(await unsigned.json(), { error: 'bad_request' });
  assert.equal(store.registerUserCalls, 0);

  const created = await fetch(registerUrl, signedFetchOptions(registerUrl, {
    method: 'POST',
    headers: {
      origin,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      identifier: 'cors@example.com',
      password: 'correct horse battery staple',
      device_id: 'device_cors'
    })
  }));
  assert.equal(created.status, 201);
  assert.equal(created.headers.get('access-control-allow-origin'), origin);

  const duplicate = await fetch(registerUrl, signedFetchOptions(registerUrl, {
    method: 'POST',
    headers: {
      origin,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      identifier: 'cors@example.com',
      password: 'correct horse battery staple',
      device_id: 'device_cors'
    })
  }));
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.headers.get('access-control-allow-origin'), origin);
  assert.deepEqual(await duplicate.json(), { error: 'user_exists' });
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
        APP_CREDENTIAL_POST_BODY_LIMIT_BYTES: '128'
      })
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const health = await fetch(`${baseUrl}/health`);
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { ok: true });

  const cardUrl = `${baseUrl}/v1/learning/cards`;
  const cardBody = JSON.stringify({
    device_id: 'anonymous_credentials',
    target_language: 'en',
    limit: 10,
    card_mode: 'new'
  });

  const unsigned = await fetch(cardUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: cardBody
  });
  assert.equal(unsigned.status, 400);
  assert.deepEqual(await unsigned.json(), { error: 'bad_request' });
  assert.equal(store.learningCardsCalls, 0);
  assert.equal(generationService.calls, 0);

  const valid = await fetch(cardUrl, signedFetchOptions(cardUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: cardBody
  }));
  assert.equal(valid.status, 200);
  assert.equal(store.learningCardsCalls, 1);

  const tampered = await fetch(
    cardUrl,
    signedFetchOptions(cardUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: cardBody
    }, {
      signUrl: `${baseUrl}/v1/learning/cards?limit=1`
    })
  );
  assert.equal(tampered.status, 400);
  assert.deepEqual(await tampered.json(), { error: 'bad_request' });

  const expired = await fetch(
    cardUrl,
    signedFetchOptions(cardUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: cardBody
    }, {
      timestamp: '2026-05-04T10:20:00.000Z'
    })
  );
  assert.equal(expired.status, 400);

  const unknownApp = await fetch(
    cardUrl,
    signedFetchOptions(cardUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: cardBody
    }, {
      appId: 'unknown_app'
    })
  );
  assert.equal(unknownApp.status, 400);

  const replayOptions = signedFetchOptions(cardUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: cardBody
  }, {
    nonce: 'replay_nonce'
  });
  assert.equal((await fetch(cardUrl, replayOptions)).status, 200);
  assert.equal((await fetch(cardUrl, replayOptions)).status, 400);

  const oversizedBody = JSON.stringify({ device_id: 'device_1', events: [], padding: 'x'.repeat(256) });
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

test('allows authenticated users to create and read own articles', async (t) => {
  const store = new WordStore({ seed: false });
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
  const register = await fetchJson(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'article-owner@example.com',
      password: 'correct horse battery staple',
      device_id: 'device_articles'
    })
  });

  const created = await fetchJson(`${baseUrl}/v1/articles`, {
    method: 'POST',
    headers: {
      ...bearerHeaders(register.session_token),
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      title: 'My first upload',
      language: 'en',
      raw_text: 'This is a learning article.',
      visibility: 'private'
    })
  });

  assert.equal(created.status, 'pending_processing');
  const listed = await fetchJson(`${baseUrl}/v1/articles`, {
    method: 'GET',
    headers: bearerHeaders(register.session_token)
  });
  assert.equal(listed.items.length, 1);
  assert.equal(listed.items[0].id, created.id);

  const detail = await fetchJson(`${baseUrl}/v1/articles/${created.id}`, {
    method: 'GET',
    headers: bearerHeaders(register.session_token)
  });
  assert.equal(detail.id, created.id);
  assert.equal(detail.visibility, 'private');
});

test('supports admin article workflow with admin token guard', async (t) => {
  const store = new WordStore({ seed: false });
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig({ ADMIN_API_TOKENS: 'admin-token-1' })
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const adminHeaders = {
    'content-type': 'application/json',
    'x-expat8-admin-token': 'admin-token-1'
  };

  const created = await fetchJson(`${baseUrl}/v1/admin/articles`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      title: 'Admin article',
      language: 'en',
      raw_text: 'Admin managed learning content.',
      visibility: 'published'
    })
  });
  assert.equal(created.status, 'pending_processing');

  const listed = await fetchJson(`${baseUrl}/v1/admin/articles`, {
    method: 'GET',
    headers: { 'x-expat8-admin-token': 'admin-token-1' }
  });
  assert.equal(listed.items.length, 1);
  assert.equal(listed.items[0].id, created.id);

  const published = await fetchJson(`${baseUrl}/v1/admin/articles/${created.id}/publish`, {
    method: 'POST',
    headers: { 'x-expat8-admin-token': 'admin-token-1' }
  });
  assert.equal(published.status, 'published');

  const patched = await fetchJson(`${baseUrl}/v1/admin/articles/${created.id}`, {
    method: 'PATCH',
    headers: {
      'content-type': 'application/json',
      'x-expat8-admin-token': 'admin-token-1'
    },
    body: JSON.stringify({
      title: 'Admin article updated',
      raw_text: 'ignored change'
    })
  });
  assert.equal(patched.title, 'Admin article updated');
  assert.equal(store.getArticleById({ articleId: created.id }).raw_text, 'Admin managed learning content.');

  const invalidVisibility = await fetch(
    `${baseUrl}/v1/admin/articles/${created.id}`,
    signedFetchOptions(`${baseUrl}/v1/admin/articles/${created.id}`, {
      method: 'PATCH',
      headers: {
        'content-type': 'application/json',
        'x-expat8-admin-token': 'admin-token-1'
      },
      body: JSON.stringify({ visibility: 'secret' })
    })
  );
  assert.equal(invalidVisibility.status, 400);

  const sharedVisibility = await fetch(
    `${baseUrl}/v1/admin/articles/${created.id}`,
    signedFetchOptions(`${baseUrl}/v1/admin/articles/${created.id}`, {
      method: 'PATCH',
      headers: {
        'content-type': 'application/json',
        'x-expat8-admin-token': 'admin-token-1'
      },
      body: JSON.stringify({ visibility: 'shared' })
    })
  );
  assert.equal(sharedVisibility.status, 400, 'shared visibility is rejected');

  const notFound = await fetch(
    `${baseUrl}/v1/admin/articles/missing_article`,
    signedFetchOptions(`${baseUrl}/v1/admin/articles/missing_article`, {
      method: 'PATCH',
      headers: {
        'content-type': 'application/json',
        'x-expat8-admin-token': 'admin-token-1'
      },
      body: JSON.stringify({ title: 'Still missing' })
    })
  );
  assert.equal(notFound.status, 404);

  const forbidden = await fetch(
    `${baseUrl}/v1/admin/articles`,
    signedFetchOptions(`${baseUrl}/v1/admin/articles`, {
      method: 'GET',
      headers: { 'x-expat8-admin-token': 'wrong-token' }
    })
  );
  assert.equal(forbidden.status, 403);
});

test('exposes article vocabulary and soft deletion rules', async (t) => {
  const store = new WordStore({ seed: false });
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
  const owner = await fetchJson(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'owner@example.com',
      password: 'correct horse battery staple',
      device_id: 'device_owner'
    })
  });
  const viewer = await fetchJson(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'viewer@example.com',
      password: 'correct horse battery staple',
      device_id: 'device_viewer'
    })
  });

  const privateArticle = store.createArticle({
    userId: owner.user_id,
    title: 'Private article',
    language: 'en',
    rawText: 'Private article text',
    visibility: 'private'
  });
  store.persistArticleVocabulary({
    articleId: privateArticle.id,
    items: [vocabItem('private term', { classification: 'article_keyword', suggestion_type: 'word' })]
  });

  const publishedArticle = store.createArticle({
    userId: owner.user_id,
    title: 'Published article',
    language: 'en',
    rawText: 'Published article text',
    visibility: 'private'
  });
  const publishedVocabulary = store.persistArticleVocabulary({
    articleId: publishedArticle.id,
    items: [vocabItem('published term', { classification: 'article_phrase', suggestion_type: 'phrase' })]
  });
  const publishedSenseId = publishedVocabulary.items[0].sense.id;
  store.speakingPromptsById.set('prompt_published_term', {
    id: 'prompt_published_term',
    word_sense_id: publishedSenseId,
    article_term_id: publishedVocabulary.items[0].articleTerm.id,
    target_text: 'This is a useful published term.',
    vi_hint: 'Day la mot cum tu huu ich da xuat ban.',
    target_phrase: 'published term',
    pronunciation_tip_vi: 'Noi cham va ro am cuoi.',
    common_mistake_vi: 'Dung doc thieu am cuoi.',
    difficulty: 'A1',
    topic: 'article-ingestion',
    status: 'approved',
    created_at: '2026-05-04T10:00:00.000Z',
    updated_at: '2026-05-04T10:00:00.000Z'
  });
  store.publishArticle({ articleId: publishedArticle.id });

  const ownerVocabulary = await fetchJson(
    `${baseUrl}/v1/articles/${privateArticle.id}/vocabulary`,
    {
      method: 'GET',
      headers: bearerHeaders(owner.session_token)
    }
  );
  assert.equal(ownerVocabulary.article_id, privateArticle.id);
  assert.equal(ownerVocabulary.items.length, 1);
  assert.equal(ownerVocabulary.items[0].classification, 'article_keyword');
  assert.equal(ownerVocabulary.items[0].suggestion_type, 'word');

  const viewerVocabulary = await fetchJson(
    `${baseUrl}/v1/articles/${publishedArticle.id}/vocabulary`,
    {
      method: 'GET',
      headers: bearerHeaders(viewer.session_token)
    }
  );
  assert.equal(viewerVocabulary.article_id, publishedArticle.id);
  assert.equal(viewerVocabulary.items.length, 1);
  assert.equal(viewerVocabulary.items[0].classification, 'article_phrase');
  assert.equal(viewerVocabulary.items[0].suggestion_type, 'phrase');
  assert.deepEqual(viewerVocabulary.items[0].speaking_prompt, {
    id: 'prompt_published_term',
    word_sense_id: publishedSenseId,
    target_text: 'This is a useful published term.',
    vi_hint: 'Day la mot cum tu huu ich da xuat ban.',
    target_phrase: 'published term',
    pronunciation_tip_vi: 'Noi cham va ro am cuoi.',
    common_mistake_vi: 'Dung doc thieu am cuoi.',
    difficulty: 'A1',
    topic: 'article-ingestion'
  });

  const viewerPrivate = await fetch(
    `${baseUrl}/v1/articles/${privateArticle.id}/vocabulary`,
    signedFetchOptions(`${baseUrl}/v1/articles/${privateArticle.id}/vocabulary`, {
      method: 'GET',
      headers: bearerHeaders(viewer.session_token)
    })
  );
  assert.equal(viewerPrivate.status, 404);

  const unauthenticated = await fetch(
    `${baseUrl}/v1/articles/${publishedArticle.id}/vocabulary`,
    signedFetchOptions(`${baseUrl}/v1/articles/${publishedArticle.id}/vocabulary`, {
      method: 'GET'
    })
  );
  assert.equal(unauthenticated.status, 401);

  const deniedDelete = await fetch(
    `${baseUrl}/v1/articles/${privateArticle.id}`,
    signedFetchOptions(`${baseUrl}/v1/articles/${privateArticle.id}`, {
      method: 'DELETE',
      headers: bearerHeaders(viewer.session_token)
    })
  );
  assert.equal(deniedDelete.status, 404);

  const deleted = await fetchJson(`${baseUrl}/v1/articles/${privateArticle.id}`, {
    method: 'DELETE',
    headers: bearerHeaders(owner.session_token)
  });
  assert.deepEqual(deleted, { success: true });

  const listed = await fetchJson(`${baseUrl}/v1/articles`, {
    method: 'GET',
    headers: bearerHeaders(owner.session_token)
  });
  assert.equal(listed.items.some((item) => item.id === privateArticle.id), false);

  const deletedVocabulary = await fetch(
    `${baseUrl}/v1/articles/${privateArticle.id}/vocabulary`,
    signedFetchOptions(`${baseUrl}/v1/articles/${privateArticle.id}/vocabulary`, {
      method: 'GET',
      headers: bearerHeaders(owner.session_token)
    })
  );
  assert.equal(deletedVocabulary.status, 404);
});

test('returns readiness without app credentials', async (t) => {
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
  const ready = await fetch(`${baseUrl}/health/ready`);

  assert.equal(ready.status, 200);
  assert.deepEqual(await ready.json(), { ok: true, db: 'ok' });
  assert.match(ready.headers.get('x-request-id') ?? '', /./);
});

test('sync processes out-of-order events deterministically', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_order_1', term: 'order one' }));
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
  const sync = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_out_of_order',
      events: [
        {
          client_event_id: 'evt_newer',
          server_word_id: 'word_order_1',
          rating: 'easy',
          occurred_at: '2026-05-04T10:31:00.000Z'
        },
        {
          client_event_id: 'evt_older',
          server_word_id: 'word_order_1',
          rating: 'easy',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });

  assert.deepEqual(sync.accepted_event_ids, ['evt_older', 'evt_newer']);
  assert.deepEqual(sync.duplicates, []);
  assert.deepEqual(sync.rejected_events, []);
});

test('speaking_drill_completed event is accepted and reflected in summary', async (t) => {
  const store = new WordStore({ seed: false });
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const sync = await fetchJson(`${baseUrl}/v1/study-events/sync`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: 'device_drill',
      events: [
        {
          client_event_id: 'drill_rec1',
          event_type: 'speaking_recorded',
          occurred_at: '2026-05-10T09:00:00.000Z',
          language: 'en',
          speaking: { attempt_id: 'att1', duration_ms: 3000, retry_count: 0 }
        },
        {
          client_event_id: 'drill_rec2',
          event_type: 'speaking_recorded',
          occurred_at: '2026-05-10T09:01:00.000Z',
          language: 'en',
          speaking: { attempt_id: 'att2', duration_ms: 4000, retry_count: 0 }
        },
        {
          client_event_id: 'drill_retry',
          event_type: 'speaking_retried',
          occurred_at: '2026-05-10T09:01:30.000Z',
          language: 'en',
          speaking: { attempt_id: 'att2', retry_count: 1 }
        },
        {
          client_event_id: 'drill_done',
          event_type: 'speaking_drill_completed',
          occurred_at: '2026-05-10T09:05:00.000Z',
          language: 'en',
          speaking: { attempt_id: 'sess1', prompts_attempted: 5, prompts_completed: 4, total_duration_ms: 300000 }
        }
      ]
    })
  });

  assert.deepEqual(sync.accepted_event_ids, ['drill_rec1', 'drill_rec2', 'drill_retry', 'drill_done']);
  assert.equal(sync.rejected_events.length, 0);
  assert.equal(store.speakingEventsByKey.size, 4);

  const summary = await fetchJson(`${baseUrl}/v1/speaking/summary?device_id=device_drill&language=en&week_start=2026-05-05`);
  assert.equal(summary.spoken_sentence_count, 2);
  assert.equal(summary.retry_count, 1);
  assert.equal(summary.retry_rate, 0.5);
  assert.equal(summary.drill_sessions_completed, 1);
  assert.equal(summary.first_recording_at, '2026-05-10T09:00:00.000Z');
});

test('speaking summary returns zeroed response for new device', async (t) => {
  const store = new WordStore({ seed: false });
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const summary = await fetchJson(`${baseUrl}/v1/speaking/summary?device_id=device_zero&language=en`);
  assert.equal(summary.spoken_sentence_count, 0);
  assert.equal(summary.retry_rate, 0);
  assert.equal(summary.drill_sessions_completed, 0);
  assert.equal(summary.first_recording_at, null);
});

test('speaking summary returns 400 when device_id is missing', async (t) => {
  const store = new WordStore({ seed: false });
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const response = await fetch(`${baseUrl}/v1/speaking/summary?language=en`, {
    headers: signedFetchOptions(`${baseUrl}/v1/speaking/summary`, {}).headers
  });
  assert.equal(response.status, 400);
});

test('GET /v1/speaking/prompts returns only approved prompts', async (t) => {
  const store = new WordStore({ seed: false });
  store.createSpeakingPrompt({ word_sense_id: null, target_text: 'Hello world.', vi_hint: 'Xin chào.', status: 'approved' });
  store.createSpeakingPrompt({ word_sense_id: null, target_text: 'Draft prompt.', vi_hint: 'Nháp.', status: 'pending_review' });
  store.createSpeakingPrompt({ word_sense_id: null, target_text: 'Rejected prompt.', vi_hint: 'Bị loại.', status: 'rejected' });

  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const url = `${baseUrl}/v1/speaking/prompts`;
  const result = await fetchJson(url, signedFetchOptions(url, {}));
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].target_text, 'Hello world.');
});

test('GET /v1/admin/speaking-prompts filters by status', async (t) => {
  const store = new WordStore({ seed: false });
  store.createSpeakingPrompt({ word_sense_id: null, target_text: 'Prompt A', vi_hint: 'A', status: 'approved' });
  store.createSpeakingPrompt({ word_sense_id: null, target_text: 'Prompt P', vi_hint: 'P', status: 'pending_review' });

  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig({ ADMIN_API_TOKENS: 'admin-tok-1' }) })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const adminHeader = { 'x-expat8-admin-token': 'admin-tok-1' };

  const all = await fetchJson(`${baseUrl}/v1/admin/speaking-prompts`, { headers: adminHeader });
  assert.equal(all.items.length, 2);

  const approved = await fetchJson(`${baseUrl}/v1/admin/speaking-prompts?status=approved`, { headers: adminHeader });
  assert.equal(approved.items.length, 1);
  assert.equal(approved.items[0].target_text, 'Prompt A');

  const pending = await fetchJson(`${baseUrl}/v1/admin/speaking-prompts?status=pending_review`, { headers: adminHeader });
  assert.equal(pending.items.length, 1);
});

test('PATCH /v1/admin/speaking-prompts/:id updates fields and returns updated object', async (t) => {
  const store = new WordStore({ seed: false });
  const created = store.createSpeakingPrompt({ word_sense_id: null, target_text: 'Old text.', vi_hint: 'Cũ.', status: 'pending_review' });

  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig({ ADMIN_API_TOKENS: 'admin-tok-2' }) })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const updated = await fetchJson(`${baseUrl}/v1/admin/speaking-prompts/${created.id}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json', 'x-expat8-admin-token': 'admin-tok-2' },
    body: JSON.stringify({ target_text: 'New text.', status: 'approved' })
  });

  assert.equal(updated.target_text, 'New text.');
  assert.equal(updated.status, 'approved');
});

test('admin speaking-prompts endpoint rejects missing app credentials with 400', async (t) => {
  const store = new WordStore({ seed: false });
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig({ ADMIN_API_TOKENS: 'admin-tok-3' }) })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  // Sending no app credentials at all → 400 (credential guard fires before admin check)
  const response = await fetch(`${baseUrl}/v1/admin/speaking-prompts`);
  assert.equal(response.status, 400);

  // Sending app credentials but wrong admin token → 403
  const withAppCred = await fetch(`${baseUrl}/v1/admin/speaking-prompts`,
    signedFetchOptions(`${baseUrl}/v1/admin/speaking-prompts`, {})
  );
  assert.equal(withAppCred.status, 403);
});

class AsyncStoreAdapter {
  constructor(store) {
    this.store = store;
  }

  async insertWord(input) {
    return this.store.insertWord(input);
  }

  async recentWords(input) {
    return this.store.recentWords(input);
  }

  async learningCards(input) {
    return this.store.learningCards(input);
  }

  async addCachedWordIds(input) {
    return this.store.addCachedWordIds(input);
  }

  async replaceCachedWordIds(input) {
    return this.store.replaceCachedWordIds(input);
  }

  async syncStudyEvents(input) {
    return this.store.syncStudyEvents(input);
  }

  async createArticle(input) {
    return this.store.createArticle(input);
  }

  async listArticles(input) {
    return this.store.listArticles(input);
  }

  async getArticleByIdForUser(input) {
    return this.store.getArticleByIdForUser(input);
  }

  async createAdminArticle(input) {
    return this.store.createAdminArticle(input);
  }

  async listAdminArticles(input) {
    return this.store.listAdminArticles(input);
  }

  async reprocessArticle(input) {
    return this.store.reprocessArticle(input);
  }

  async publishArticle(input) {
    return this.store.publishArticle(input);
  }

  async listVocabularyReviewItems(input) {
    return this.store.listVocabularyReviewItems(input);
  }

  async reviewVocabularyItem(input) {
    return this.store.reviewVocabularyItem(input);
  }

  async listContentPacks(input) {
    return this.store.listContentPacks(input);
  }

  async getContentPackById(input) {
    return this.store.getContentPackById(input);
  }

  async recordStudyEvent(input) {
    return this.store.recordStudyEvent(input);
  }

  async getProficiency(input) {
    return this.store.getProficiency(input);
  }

  async registerUser(input) {
    return this.store.registerUser(input);
  }

  async createUserSession(input) {
    return this.store.createUserSession(input);
  }

  async resolveUserSession(input) {
    return this.store.resolveUserSession(input);
  }

  async revokeUserSession(input) {
    return this.store.revokeUserSession(input);
  }

  async getMe(input) {
    return this.store.getMe(input);
  }

  async getArticleVocabulary(input) {
    return this.store.getArticleVocabulary(input);
  }

  async softDeleteArticle(input) {
    return this.store.softDeleteArticle(input);
  }

  async patchAdminArticle(input) {
    return this.store.patchAdminArticle(input);
  }

  async healthCheck(input) {
    return this.store.healthCheck(input);
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

function postLearningCards(baseUrl, body, headers = {}) {
  return fetchJson(`${baseUrl}/v1/learning/cards`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...headers
    },
    body: JSON.stringify(body)
  });
}

function bearerHeaders(token) {
  return { authorization: `Bearer ${token}` };
}

function wordInput(overrides = {}) {
  return {
    term: 'identity',
    language: 'en',
    meaning_vi: 'dinh danh',
    part_of_speech: 'noun',
    ipa: '/aɪˈden.tə.ti/',
    vietnamese_pronunciation: 'ai-den-ti-ti',
    example: 'Identity helps track progress.',
    example_vi: 'Dinh danh giup theo doi tien do.',
    difficulty: 'A1',
    topics: ['account'],
    ...overrides
  };
}

function vocabItem(term, overrides = {}) {
  return {
    term,
    language: 'en',
    meaning_vi: `Nghia cua ${term}`,
    part_of_speech: 'noun',
    ipa: '/na/',
    vietnamese_pronunciation: term,
    example: `${term} in article`,
    example_vi: `${term} trong bai viet`,
    difficulty: 'A1',
    topics: ['article-ingestion'],
    ...overrides
  };
}

class CountingStore extends AsyncStoreAdapter {
  constructor() {
    super(new WordStore());
    this.learningCardsCalls = 0;
    this.registerUserCalls = 0;
    this.syncStudyEventsCalls = 0;
  }

  async learningCards(input) {
    this.learningCardsCalls += 1;
    return super.learningCards(input);
  }

  async registerUser(input) {
    this.registerUserCalls += 1;
    return super.registerUser(input);
  }

  async syncStudyEvents(input) {
    this.syncStudyEventsCalls += 1;
    return super.syncStudyEvents(input);
  }
}
