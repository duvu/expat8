import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { WordStore } from '../src/word_store.js';
import { createApp } from '../src/app.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

function makeStore() {
  return new WordStore({ seed: false });
}

function seedDeviceWordState(store, { deviceId, wordId, language = 'en', reviewCount = 1, lastStudiedAt = '2026-05-10T10:00:00.000Z' }) {
  const ownerKey = `device:${deviceId}:word:${wordId}`;
  store.wordStatesByOwnerWord.set(ownerKey, {
    user_id: null,
    device_id: deviceId,
    word_id: wordId,
    language,
    status: 'review',
    last_rating: 'easy',
    last_studied_at: lastStudiedAt,
    next_review_at: '2026-05-17T10:00:00.000Z',
    ease_factor: 2.5,
    review_count: reviewCount,
    updated_at: lastStudiedAt
  });
}

function seedUserWordState(store, { userId, wordId, language = 'en', reviewCount = 1, lastStudiedAt = '2026-05-10T10:00:00.000Z' }) {
  const ownerKey = `user:${userId}:word:${wordId}`;
  store.wordStatesByOwnerWord.set(ownerKey, {
    user_id: userId,
    device_id: null,
    word_id: wordId,
    language,
    status: 'review',
    last_rating: 'easy',
    last_studied_at: lastStudiedAt,
    next_review_at: '2026-05-17T10:00:00.000Z',
    ease_factor: 2.5,
    review_count: reviewCount,
    updated_at: lastStudiedAt
  });
}

function seedDeviceCachedWords(store, { deviceId, wordIds, observedAt = '2026-05-10T10:00:00.000Z' }) {
  const ownerKey = `device:${deviceId}`;
  store.cachedWordIdsByOwner.set(ownerKey, {
    wordIds: new Set(wordIds),
    observed_at: observedAt
  });
}

function seedUserCachedWords(store, { userId, wordIds, observedAt = '2026-05-10T10:00:00.000Z' }) {
  const ownerKey = `user:${userId}`;
  store.cachedWordIdsByOwner.set(ownerKey, {
    wordIds: new Set(wordIds),
    observed_at: observedAt
  });
}

function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

function bearerHeaders(token) {
  return { authorization: `Bearer ${token}` };
}

async function fetchJson(url, options) {
  const response = await fetch(url, signedFetchOptions(url, options));
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json();
}

// ---------------------------------------------------------------------------
// 4.1 — Unit tests: claim word states on registration
// ---------------------------------------------------------------------------

test('registerUser claims device-only word states (no conflict)', () => {
  const store = makeStore();
  const deviceId = 'device_claim_1';

  // Seed 3 device-only word states
  for (let i = 0; i < 3; i++) {
    store.insertWord(wordInput({ id: `word_${i}`, term: `term${i}` }));
    seedDeviceWordState(store, { deviceId, wordId: `word_${i}` });
  }

  // Register: should claim all 3
  const { user } = store.registerUser({
    identifier: 'claim@test.com',
    password: 'password123!',
    displayName: 'Claimer',
    deviceId
  });

  // Verify: device states gone, user states exist
  for (let i = 0; i < 3; i++) {
    const deviceKey = `device:${deviceId}:word:word_${i}`;
    const userKey = `user:${user.id}:word:word_${i}`;
    assert.equal(store.wordStatesByOwnerWord.has(deviceKey), false, `device state for word_${i} should be removed`);
    assert.equal(store.wordStatesByOwnerWord.has(userKey), true, `user state for word_${i} should exist`);
    assert.equal(store.wordStatesByOwnerWord.get(userKey).user_id, user.id);
  }
});

test('registerUser resolves conflict: device wins (higher review_count)', () => {
  const store = makeStore();
  const deviceId = 'device_conflict_1';

  store.insertWord(wordInput({ id: 'word_conflict', term: 'conflict' }));

  // Register a user first with a different device (so no claim of our target device)
  const { user } = store.registerUser({
    identifier: 'preexist@test.com',
    password: 'securepass0!',
    displayName: 'Pre',
    deviceId: 'unrelated_device'
  });

  // Manually seed a user word state with review_count=2
  seedUserWordState(store, { userId: user.id, wordId: 'word_conflict', reviewCount: 2, lastStudiedAt: '2026-05-05T10:00:00.000Z' });

  // Seed device state with review_count=5 (device wins)
  seedDeviceWordState(store, { deviceId, wordId: 'word_conflict', reviewCount: 5, lastStudiedAt: '2026-05-10T10:00:00.000Z' });

  // Sign in with the target device — triggers claim, device state should win
  store.createUserSession({
    identifier: 'preexist@test.com',
    password: 'securepass0!',
    deviceId
  });

  const userKey = `user:${user.id}:word:word_conflict`;
  const state = store.wordStatesByOwnerWord.get(userKey);
  assert.equal(state.review_count, 5, 'device state with higher review_count should win');
  assert.equal(state.user_id, user.id);

  // Device key should be removed
  assert.equal(store.wordStatesByOwnerWord.has(`device:${deviceId}:word:word_conflict`), false);
});

test('createUserSession resolves conflict: device state wins (higher review_count)', () => {
  const store = makeStore();
  const deviceId = 'device_conflict_2';

  store.insertWord(wordInput({ id: 'word_c1', term: 'contested' }));

  // Register user first (with a different device so no claim happens yet)
  const { user } = store.registerUser({
    identifier: 'conflict@test.com',
    password: 'securepass1!',
    displayName: 'Conflict User',
    deviceId: 'other_device'
  });

  // Seed user word state with review_count=2
  seedUserWordState(store, { userId: user.id, wordId: 'word_c1', reviewCount: 2, lastStudiedAt: '2026-05-08T10:00:00.000Z' });

  // Seed device state with review_count=5 (device wins)
  seedDeviceWordState(store, { deviceId, wordId: 'word_c1', reviewCount: 5, lastStudiedAt: '2026-05-10T10:00:00.000Z' });

  // Sign in with deviceId — triggers claim
  store.createUserSession({
    identifier: 'conflict@test.com',
    password: 'securepass1!',
    deviceId
  });

  // Device state should win: user key should have review_count=5
  const userKey = `user:${user.id}:word:word_c1`;
  const state = store.wordStatesByOwnerWord.get(userKey);
  assert.equal(state.review_count, 5, 'device state with higher review_count should win');
  assert.equal(state.user_id, user.id);

  // Device key should be gone
  const deviceKey = `device:${deviceId}:word:word_c1`;
  assert.equal(store.wordStatesByOwnerWord.has(deviceKey), false);
});

test('createUserSession resolves conflict: user state wins (higher review_count)', () => {
  const store = makeStore();
  const deviceId = 'device_conflict_3';

  store.insertWord(wordInput({ id: 'word_c2', term: 'retained' }));

  // Register user (different device)
  const { user } = store.registerUser({
    identifier: 'winner@test.com',
    password: 'securepass2!',
    displayName: 'Winner User',
    deviceId: 'other_device_2'
  });

  // User state with review_count=10
  seedUserWordState(store, { userId: user.id, wordId: 'word_c2', reviewCount: 10, lastStudiedAt: '2026-05-09T10:00:00.000Z' });

  // Device state with review_count=3 (user wins)
  seedDeviceWordState(store, { deviceId, wordId: 'word_c2', reviewCount: 3, lastStudiedAt: '2026-05-12T10:00:00.000Z' });

  // Sign in — triggers claim
  store.createUserSession({
    identifier: 'winner@test.com',
    password: 'securepass2!',
    deviceId
  });

  // User state should still have review_count=10
  const userKey = `user:${user.id}:word:word_c2`;
  const state = store.wordStatesByOwnerWord.get(userKey);
  assert.equal(state.review_count, 10, 'user state with higher review_count should be retained');

  // Device key should be gone
  const deviceKey = `device:${deviceId}:word:word_c2`;
  assert.equal(store.wordStatesByOwnerWord.has(deviceKey), false);
});

test('createUserSession resolves conflict: equal review_count, device has later last_studied_at → device wins', () => {
  const store = makeStore();
  const deviceId = 'device_conflict_4';

  store.insertWord(wordInput({ id: 'word_c3', term: 'tiebreak' }));

  const { user } = store.registerUser({
    identifier: 'tiebreak@test.com',
    password: 'securepass3!',
    displayName: 'Tie User',
    deviceId: 'other_device_3'
  });

  // Same review_count, user has earlier date
  seedUserWordState(store, { userId: user.id, wordId: 'word_c3', reviewCount: 4, lastStudiedAt: '2026-05-08T10:00:00.000Z' });
  // Device has later date
  seedDeviceWordState(store, { deviceId, wordId: 'word_c3', reviewCount: 4, lastStudiedAt: '2026-05-12T10:00:00.000Z' });

  store.createUserSession({
    identifier: 'tiebreak@test.com',
    password: 'securepass3!',
    deviceId
  });

  const userKey = `user:${user.id}:word:word_c3`;
  const state = store.wordStatesByOwnerWord.get(userKey);
  assert.equal(state.last_studied_at, '2026-05-12T10:00:00.000Z', 'device state with later date should win on tie');
});

test('createUserSession resolves conflict: equal review_count, same last_studied_at → user wins', () => {
  const store = makeStore();
  const deviceId = 'device_conflict_5';

  store.insertWord(wordInput({ id: 'word_c4', term: 'identical' }));

  const { user } = store.registerUser({
    identifier: 'same@test.com',
    password: 'securepass4!',
    displayName: 'Same User',
    deviceId: 'other_device_4'
  });

  const sameDate = '2026-05-10T10:00:00.000Z';
  seedUserWordState(store, { userId: user.id, wordId: 'word_c4', reviewCount: 4, lastStudiedAt: sameDate });
  seedDeviceWordState(store, { deviceId, wordId: 'word_c4', reviewCount: 4, lastStudiedAt: sameDate });

  store.createUserSession({
    identifier: 'same@test.com',
    password: 'securepass4!',
    deviceId
  });

  const userKey = `user:${user.id}:word:word_c4`;
  const state = store.wordStatesByOwnerWord.get(userKey);
  // User state wins on equal — original user state should be retained
  assert.equal(state.last_studied_at, sameDate);
  assert.equal(state.user_id, user.id);

  // Device key gone
  assert.equal(store.wordStatesByOwnerWord.has(`device:${deviceId}:word:word_c4`), false);
});

test('registerUser with no deviceId does not crash', () => {
  const store = makeStore();
  const { user } = store.registerUser({
    identifier: 'nodevice@test.com',
    password: 'password123!',
    displayName: 'No Device'
    // deviceId omitted
  });
  assert.ok(user.id);
});

test('claim ignores word states belonging to other devices', () => {
  const store = makeStore();
  const deviceA = 'device_a';
  const deviceB = 'device_b';

  store.insertWord(wordInput({ id: 'word_other', term: 'other' }));
  seedDeviceWordState(store, { deviceId: deviceA, wordId: 'word_other' });
  seedDeviceWordState(store, { deviceId: deviceB, wordId: 'word_other' });

  // Register with deviceA only
  const { user } = store.registerUser({
    identifier: 'onlya@test.com',
    password: 'password123!',
    displayName: 'A Only',
    deviceId: deviceA
  });

  // deviceA's state should be claimed
  assert.equal(store.wordStatesByOwnerWord.has(`device:${deviceA}:word:word_other`), false);
  assert.equal(store.wordStatesByOwnerWord.has(`user:${user.id}:word:word_other`), true);

  // deviceB's state should remain untouched
  assert.equal(store.wordStatesByOwnerWord.has(`device:${deviceB}:word:word_other`), true);
});

// ---------------------------------------------------------------------------
// 4.2 — Unit tests: claim cached words
// ---------------------------------------------------------------------------

test('registerUser claims device cached words (no conflict)', () => {
  const store = makeStore();
  const deviceId = 'device_cache_1';

  seedDeviceCachedWords(store, { deviceId, wordIds: ['w1', 'w2', 'w3'] });

  const { user } = store.registerUser({
    identifier: 'cache@test.com',
    password: 'password123!',
    displayName: 'Cache User',
    deviceId
  });

  // Device cache should be gone
  assert.equal(store.cachedWordIdsByOwner.has(`device:${deviceId}`), false);

  // User cache should have all 3
  const userCache = store.cachedWordIdsByOwner.get(`user:${user.id}`);
  assert.ok(userCache);
  assert.equal(userCache.wordIds.size, 3);
  assert.ok(userCache.wordIds.has('w1'));
  assert.ok(userCache.wordIds.has('w2'));
  assert.ok(userCache.wordIds.has('w3'));
});

test('createUserSession merges cached words, removing duplicates', () => {
  const store = makeStore();
  const deviceId = 'device_cache_2';

  // Register user with different device
  const { user } = store.registerUser({
    identifier: 'cachemerge@test.com',
    password: 'password123!',
    displayName: 'Merge User',
    deviceId: 'other_dev'
  });

  // Seed user cache with w1, w2
  seedUserCachedWords(store, { userId: user.id, wordIds: ['w1', 'w2'] });

  // Seed device cache with w2 (duplicate), w3 (new)
  seedDeviceCachedWords(store, { deviceId, wordIds: ['w2', 'w3'] });

  // Sign in with the device
  store.createUserSession({
    identifier: 'cachemerge@test.com',
    password: 'password123!',
    deviceId
  });

  // Device cache gone
  assert.equal(store.cachedWordIdsByOwner.has(`device:${deviceId}`), false);

  // User cache should have w1, w2, w3 (merged, no dups)
  const userCache = store.cachedWordIdsByOwner.get(`user:${user.id}`);
  assert.equal(userCache.wordIds.size, 3);
  assert.ok(userCache.wordIds.has('w1'));
  assert.ok(userCache.wordIds.has('w2'));
  assert.ok(userCache.wordIds.has('w3'));
});

test('claim cached words with no device cache is a no-op', () => {
  const store = makeStore();

  const { user } = store.registerUser({
    identifier: 'nocache@test.com',
    password: 'password123!',
    displayName: 'No Cache',
    deviceId: 'device_nocache'
  });

  // No crash, no user cache created from nothing
  const userCache = store.cachedWordIdsByOwner.get(`user:${user.id}`);
  assert.equal(userCache, undefined);
});

// ---------------------------------------------------------------------------
// 4.3 — Integration test: study anonymously → register → exam succeeds
// ---------------------------------------------------------------------------

test('device-only study → register → exam start succeeds (full flow)', async (t) => {
  const store = makeStore();
  const deviceId = 'device_exam_flow';

  // Seed 7 words (minimum 5 needed for exam, extra for distractors)
  for (let i = 0; i < 7; i++) {
    store.insertWord(wordInput({ id: `exam_word_${i}`, term: `examterm${i}` }));
  }
  // Also seed some distractor words (needed for exam question generation)
  for (let i = 0; i < 6; i++) {
    store.insertWord(wordInput({ id: `distractor_${i}`, term: `distractor${i}`, meaning_vi: `distractor_meaning_${i}` }));
  }

  // Study 7 words as anonymous device (no userId)
  for (let i = 0; i < 7; i++) {
    store.recordStudyEvent({
      deviceId,
      event: {
        client_event_id: `anon_evt_${i}`,
        server_word_id: `exam_word_${i}`,
        rating: 'easy',
        occurred_at: `2026-05-10T1${i}:00:00.000Z`
      },
      language: 'en',
      userId: null
    });
  }

  // Verify: device states exist, no user states
  for (let i = 0; i < 7; i++) {
    const deviceKey = `device:${deviceId}:word:exam_word_${i}`;
    assert.ok(store.wordStatesByOwnerWord.has(deviceKey), `device state for word ${i} should exist before registration`);
  }

  // Register with the same deviceId → should claim all device states
  const { user, session_token } = store.registerUser({
    identifier: 'examiner@test.com',
    password: 'password123!',
    displayName: 'Examiner',
    deviceId
  });

  // Verify: device states gone, user states exist
  for (let i = 0; i < 7; i++) {
    const deviceKey = `device:${deviceId}:word:exam_word_${i}`;
    const userKey = `user:${user.id}:word:exam_word_${i}`;
    assert.equal(store.wordStatesByOwnerWord.has(deviceKey), false, `device state ${i} should be removed after registration`);
    assert.ok(store.wordStatesByOwnerWord.has(userKey), `user state ${i} should exist after registration`);
  }

  // Now start an exam — should succeed (7 >= 5 words)
  const examResult = store.startExamSession({ userId: user.id, language: 'en' });
  assert.ok(!examResult.error, `exam should not return an error, got: ${examResult.error}`);
  assert.ok(examResult.session_id, 'exam should return a session_id');
  assert.ok(examResult.question_count >= 5, `should have at least 5 questions, got: ${examResult.question_count}`);
});

test('device-only study → sign-in → exam start succeeds (full flow via createUserSession)', async (t) => {
  const store = makeStore();
  const deviceId = 'device_signin_exam';

  // Seed words
  for (let i = 0; i < 7; i++) {
    store.insertWord(wordInput({ id: `signin_word_${i}`, term: `signinterm${i}` }));
  }
  for (let i = 0; i < 6; i++) {
    store.insertWord(wordInput({ id: `signin_dist_${i}`, term: `signindist${i}`, meaning_vi: `dist_vi_${i}` }));
  }

  // First register user with a DIFFERENT device (no claim yet)
  store.registerUser({
    identifier: 'signinexam@test.com',
    password: 'password123!',
    displayName: 'SignIn Examiner',
    deviceId: 'some_other_device'
  });

  // Study words anonymously on this device
  for (let i = 0; i < 7; i++) {
    store.recordStudyEvent({
      deviceId,
      event: {
        client_event_id: `signin_evt_${i}`,
        server_word_id: `signin_word_${i}`,
        rating: 'easy',
        occurred_at: `2026-05-10T1${i}:00:00.000Z`
      },
      language: 'en',
      userId: null
    });
  }

  // Sign in with the study device → should claim
  const { user } = store.createUserSession({
    identifier: 'signinexam@test.com',
    password: 'password123!',
    deviceId
  });

  // Exam should work
  const examResult = store.startExamSession({ userId: user.id, language: 'en' });
  assert.ok(!examResult.error, `exam should not error, got: ${examResult.error}`);
  assert.ok(examResult.session_id);
  assert.ok(examResult.question_count >= 5);
});

test('without claim, exam returns INSUFFICIENT_WORDS for device-only states', () => {
  const store = makeStore();
  const deviceId = 'device_no_claim';

  // Seed and study words as device only
  for (let i = 0; i < 7; i++) {
    store.insertWord(wordInput({ id: `nc_word_${i}`, term: `ncterm${i}` }));
    seedDeviceWordState(store, { deviceId, wordId: `nc_word_${i}` });
  }
  for (let i = 0; i < 6; i++) {
    store.insertWord(wordInput({ id: `nc_dist_${i}`, term: `ncdist${i}`, meaning_vi: `nc_meaning_${i}` }));
  }

  // Manually create a user (without going through registerUser which would trigger claim)
  const userId = 'user_no_claim';
  store.usersById.set(userId, {
    id: userId,
    identifier: 'noclaim@test.com',
    display_name: 'NoClaim',
    password_hash: 'x',
    created_at: '2026-05-01T00:00:00.000Z',
    updated_at: '2026-05-01T00:00:00.000Z'
  });

  // Try exam — should fail since no user word states exist
  const examResult = store.startExamSession({ userId, language: 'en' });
  assert.equal(examResult.error, 'INSUFFICIENT_WORDS');
  assert.equal(examResult.found, 0);
});

// ---------------------------------------------------------------------------
// 4.3b — HTTP-level integration test
// ---------------------------------------------------------------------------

test('HTTP flow: study anonymously → register → exam start succeeds', async (t) => {
  const store = makeStore();
  const deviceId = 'device_http_exam';

  // Seed enough words
  for (let i = 0; i < 7; i++) {
    store.insertWord(wordInput({ id: `http_word_${i}`, term: `httpterm${i}` }));
  }
  for (let i = 0; i < 6; i++) {
    store.insertWord(wordInput({ id: `http_dist_${i}`, term: `httpdist${i}`, meaning_vi: `http_meaning_${i}` }));
  }

  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig() })
  );
  await listen(server);
  t.after(() => server.close());
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  // 1. Study events without auth (device-only)
  for (let i = 0; i < 7; i++) {
    const body = JSON.stringify({
      device_id: deviceId,
      client_event_id: `http_evt_${i}`,
      word_id: `http_word_${i}`,
      rating: 'easy',
      occurred_at: `2026-05-10T1${i}:00:00.000Z`
    });
    const response = await fetch(
      `${baseUrl}/v1/study-events`,
      signedFetchOptions(`${baseUrl}/v1/study-events`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body
      })
    );
    assert.ok(response.status >= 200 && response.status < 300, `study event ${i} should succeed, got ${response.status}`);
  }

  // Verify device states exist (store-level check)
  for (let i = 0; i < 7; i++) {
    const deviceKey = `device:${deviceId}:word:http_word_${i}`;
    assert.ok(store.wordStatesByOwnerWord.has(deviceKey), `device state ${i} should exist`);
  }

  // 2. Register with the same device
  const registered = await fetchJson(`${baseUrl}/v1/users/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'httpexam@test.com',
      password: 'correct horse battery staple',
      display_name: 'HTTP Examiner',
      device_id: deviceId
    })
  });
  assert.ok(registered.session_token);
  assert.ok(registered.user_id);

  // 3. Start exam with the session token
  const examBody = JSON.stringify({ language: 'en' });
  const examResponse = await fetch(
    `${baseUrl}/v1/exam/start`,
    signedFetchOptions(`${baseUrl}/v1/exam/start`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...bearerHeaders(registered.session_token)
      },
      body: examBody
    })
  );
  assert.equal(examResponse.status, 201, `exam start should succeed, got ${examResponse.status}`);
  const examData = await examResponse.json();
  assert.ok(examData.session_id);
  assert.ok(examData.question_count >= 5);
});
