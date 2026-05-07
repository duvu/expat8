import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('serves word feed, recent words, and idempotent sync', async (t) => {
  const store = new WordStore();
  seedTestDeviceProficiencies(store);
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
          rating: 'easy',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });
  assert.deepEqual(sync.accepted_event_ids, ['evt_1']);
  assert.equal(sync.proficiency.scale, 'cefr');
  assert.equal(sync.proficiency.level_index, 0);
  assert.equal(sync.proficiency.level, 'A1');
  assert.equal(sync.proficiency.proficiency_scale, 'cefr');
  assert.equal(sync.proficiency.proficiency_level, 'A1');
  assert.equal(sync.proficiency.proficiency_level_index, 0);

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
          rating: 'easy',
          occurred_at: '2026-05-04T10:30:00.000Z'
        }
      ]
    })
  });
  assert.deepEqual(retry.accepted_event_ids, ['evt_1']);
  assert.equal(store.studyEventsByClientId.size, 1);

  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=device_1&language=en`);
  assert.equal(proficiency.scale, 'cefr');
  assert.equal(proficiency.level_index, 0);
  assert.equal(proficiency.level, 'A1');
  assert.equal(proficiency.proficiency_scale, 'cefr');
  assert.equal(proficiency.proficiency_level, 'A1');
  assert.equal(proficiency.proficiency_level_index, 0);
});

test('omits compatibility aliases when strict proficiency mode is enabled', async (t) => {
  const store = new WordStore({ seed: false });
  seedTestDeviceProficiencies(store);
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig({ PROFICIENCY_COMPATIBILITY_MODE: 'strict' })
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=device_zh&language=zh`);

  assert.equal(proficiency.scale, 'hsk');
  assert.equal(proficiency.level, 'HSK1');
  assert.equal(proficiency.level_index, 0);
  assert.equal('proficiency_scale' in proficiency, false);
  assert.equal('proficiency_level' in proficiency, false);
  assert.equal('proficiency_level_index' in proficiency, false);
});

test('returns HSK proficiency contract for Chinese language lookup', async (t) => {
  const store = new WordStore({ seed: false });
  seedTestDeviceProficiencies(store);
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
  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=device_zh&language=zh`);

  assert.equal(proficiency.scale, 'hsk');
  assert.equal(proficiency.level, 'HSK1');
  assert.equal(proficiency.level_index, 0);
});

test('does not call AI generation when database inventory is empty', async (t) => {
  const store = new WordStore({ seed: false });
  const generationService = {
    calls: 0,
    async generateAndStore() {
      this.calls += 1;
      throw new Error('AI generation must not run in the mobile request path');
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
  const next = await fetchJson(`${baseUrl}/v1/words/next?limit=5&target_language=en`);

  assert.deepEqual(next.items, []);
  assert.equal(generationService.calls, 0);
});

test('serves backend-selected learning cards with target and actual mix metadata', async (t) => {
  const store = new WordStore({ seed: false });
  for (let index = 0; index < 17; index += 1) {
    store.insertWord(wordInput({
      id: `review_${index}`,
      term: `review ${index}`,
      created_at: `2026-05-01T00:${index.toString().padStart(2, '0')}:00.000Z`,
      updated_at: `2026-05-01T00:${index.toString().padStart(2, '0')}:00.000Z`
    }));
    store.recordStudyEvent({
      deviceId: 'device_mix',
      event: {
        client_event_id: `evt_review_${index}`,
        server_word_id: `review_${index}`,
        local_word_id: `local_review_${index}`,
        rating: 'hard',
        occurred_at: `2026-05-01T01:${index.toString().padStart(2, '0')}:00.000Z`
      }
    });
  }
  for (let index = 0; index < 3; index += 1) {
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
  const batch = await fetchJson(`${baseUrl}/v1/learning/cards?device_id=device_mix&limit=20&target_language=en`);

  assert.deepEqual(batch.target_mix, { new: 3, review: 17 });
  assert.deepEqual(batch.actual_mix, { new: 3, review: 17 });
  assert.equal(batch.items.filter((item) => item.card_type === 'new').length, 3);
  assert.equal(batch.items.filter((item) => item.card_type === 'review').length, 17);
  assert.ok(batch.items.every((item) => typeof item.selection_reason === 'string'));
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

  const batch = await fetchJson(`${baseUrl}/v1/learning/cards?device_id=device_cache&limit=1&target_language=en`);
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

test('uses device_id to resolve proficiency when word feed omits explicit level', async (t) => {
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

  const next = await fetchJson(`${baseUrl}/v1/words/next?limit=1&target_language=en&device_id=device_feed`);
  assert.equal(next.items[0].server_word_id, 'word_a2');
});

test('applies proficiency filtering together with server-word exclusion', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord({
    id: 'word_b1_a',
    term: 'measure',
    language: 'en',
    meaning_vi: 'do luong',
    part_of_speech: 'verb',
    ipa: '/ˈmeʒ.ər/',
    vietnamese_pronunciation: 'me-zher',
    example: 'We measure the result every week.',
    example_vi: 'Chung toi do luong ket qua moi tuan.',
    difficulty: 'B1',
    topics: ['work']
  });
  store.insertWord({
    id: 'word_b1_b',
    term: 'improve',
    language: 'en',
    meaning_vi: 'cai thien',
    part_of_speech: 'verb',
    ipa: '/ɪmˈpruːv/',
    vietnamese_pronunciation: 'im-proov',
    example: 'We improve the process every month.',
    example_vi: 'Chung toi cai thien quy trinh moi thang.',
    difficulty: 'B1',
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
  const next = await fetchJson(
    `${baseUrl}/v1/words/next?limit=1&target_language=en&proficiency_level=B1&exclude_server_word_id=word_b1_b`
  );

  assert.equal(next.items.length, 1);
  assert.equal(next.items[0].server_word_id, 'word_b1_a');
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

  const first = await fetchJson(`${baseUrl}/v1/words/next?limit=1&target_language=en&device_id=device_identity`, {
    headers: bearerHeaders(signedIn.session_token)
  });
  assert.equal(first.items[0].server_word_id, 'word_identity_b');

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

  const second = await fetchJson(`${baseUrl}/v1/words/next?limit=1&target_language=en&device_id=device_identity`, {
    headers: bearerHeaders(signedIn.session_token)
  });
  assert.equal(second.items[0].server_word_id, 'word_identity_a');

  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=device_identity&language=en`, {
    headers: bearerHeaders(signedIn.session_token)
  });
  assert.equal(proficiency.user_id, registered.user_id);

  const foreignProficiency = await fetch(
    `${baseUrl}/v1/proficiency?device_id=device_other&language=en`,
    signedFetchOptions(`${baseUrl}/v1/proficiency?device_id=device_other&language=en`, {
      headers: bearerHeaders(signedIn.session_token)
    })
  );
  assert.equal(foreignProficiency.status, 403);

  const signOut = await fetchJson(`${baseUrl}/v1/users/sign-out`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...bearerHeaders(signedIn.session_token)
    },
    body: JSON.stringify({})
  });
  assert.equal(signOut.success, true);

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
}

test('filters recent words by exclude_server_word_id', async (t) => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_recent_a', term: 'alpha' }));
  store.insertWord(wordInput({ id: 'word_recent_b', term: 'beta' }));
  store.insertWord(wordInput({ id: 'word_recent_c', term: 'gamma' }));
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const all = await fetchJson(`${baseUrl}/v1/words/recent?limit=10&target_language=en`);
  assert.equal(all.items.length, 3);

  const filtered = await fetchJson(
    `${baseUrl}/v1/words/recent?limit=10&target_language=en&exclude_server_word_id=word_recent_a&exclude_server_word_id=word_recent_b`
  );
  assert.equal(filtered.items.length, 1);
  assert.equal(filtered.items[0].server_word_id, 'word_recent_c');
});

test('enforces rate limit on registration and sign-in', async (t) => {
  const store = new WordStore({ seed: false });
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig({ AUTH_RATE_LIMIT_REGISTER: '2', AUTH_RATE_LIMIT_SIGN_IN: '2' })
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const registerUrl = `${baseUrl}/v1/users/register`;
  const registerBody = JSON.stringify({ identifier: 'rl@example.com', password: 'pass1234', device_id: 'device_rl' });

  // First two requests succeed (or 409 if duplicate) — not 429
  for (let i = 0; i < 2; i++) {
    const res = await fetch(registerUrl, signedFetchOptions(registerUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: registerBody
    }));
    assert.ok(res.status !== 429, `request ${i + 1} should not be rate-limited`);
  }

  // Third request should be rate-limited
  const limited = await fetch(registerUrl, signedFetchOptions(registerUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: registerBody
  }));
  assert.equal(limited.status, 429);
  assert.deepEqual(await limited.json(), { error: 'too_many_requests' });

  // Sign-in rate limit
  const signInUrl = `${baseUrl}/v1/users/sign-in`;
  const signInBody = JSON.stringify({ identifier: 'rl@example.com', password: 'wrong', device_id: 'device_rl' });
  for (let i = 0; i < 2; i++) {
    const res = await fetch(signInUrl, signedFetchOptions(signInUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: signInBody
    }));
    assert.ok(res.status !== 429, `sign-in ${i + 1} should not be rate-limited`);
  }
  const signInLimited = await fetch(signInUrl, signedFetchOptions(signInUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: signInBody
  }));
  assert.equal(signInLimited.status, 429);
  assert.deepEqual(await signInLimited.json(), { error: 'too_many_requests' });
});

test('rejects invalid bearer token with 401 on optional-auth endpoints', async (t) => {
  const store = new WordStore();
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const url = `${baseUrl}/v1/words/next?limit=1&target_language=en`;
  const response = await fetch(url, signedFetchOptions(url, {
    headers: { authorization: 'Bearer totally_fake_token_xyz' }
  }));
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'invalid_session' });
});

test('rejects study event with invalid occurred_at timestamp', async (t) => {
  const store = new WordStore();
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const url = `${baseUrl}/v1/study-events`;
  const body = JSON.stringify({
    device_id: 'device_invalid_ts',
    client_event_id: 'evt_invalid_ts',
    word_id: 'word_reliable',
    rating: 'easy',
    occurred_at: 'not-a-date'
  });
  const response = await fetch(url, signedFetchOptions(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body
  }));
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'bad_request' });
});

test('rejects unknown language code on /words/next', async (t) => {
  const store = new WordStore();
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const url = `${baseUrl}/v1/words/next?limit=1&target_language=xx_invalid`;
  const response = await fetch(url, signedFetchOptions(url));
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'bad_request' });
});

test('rejects unknown language code on /words/recent', async (t) => {
  const store = new WordStore();
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const url = `${baseUrl}/v1/words/recent?limit=1&target_language=xx_invalid`;
  const response = await fetch(url, signedFetchOptions(url));
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'bad_request' });
});

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

function bearerHeaders(token) {
  return { authorization: `Bearer ${token}` };
}

function seedTestDeviceProficiencies(store) {
  store.getProficiency({ deviceId: 'device_1', language: 'en' });
  store.getProficiency({ deviceId: 'device_zh', language: 'zh' });
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

class CountingStore extends AsyncStoreAdapter {
  constructor() {
    super(new WordStore());
    this.findNewWordsCalls = 0;
    this.registerUserCalls = 0;
    this.syncStudyEventsCalls = 0;
  }

  async findNewWords(input) {
    this.findNewWordsCalls += 1;
    return super.findNewWords(input);
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
