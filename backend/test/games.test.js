import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { isPlausibleGameRound, normalizeGameRound, rankLeaderboard } from '../src/game_rounds.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

function round(overrides = {}) {
  return {
    client_round_id: `round_${Math.random().toString(36).slice(2)}`,
    game: 'word_blaster',
    mode: 'classic',
    language: 'en',
    score: 2400,
    correct_count: 12,
    answered_count: 15,
    best_combo: 7,
    wave: 2,
    duration_ms: 90_000,
    completed_at: new Date().toISOString(),
    ...overrides
  };
}

async function startServer(t, store = new WordStore({ seed: false })) {
  const server = http.createServer(
    createApp({ store, generationService: null, config: loadTestConfig({ ADMIN_API_TOKENS: 'admin-token' }) })
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  return { store, baseUrl: `http://127.0.0.1:${server.address().port}` };
}

async function call(url, options = {}) {
  const response = await fetch(url, signedFetchOptions(url, options));
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : null };
}

function post(url, body, headers = {}) {
  return call(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body)
  });
}

async function register(baseUrl, identifier, deviceId, displayName = null) {
  const { body } = await post(`${baseUrl}/v1/users/register`, {
    identifier,
    password: 'correct horse battery',
    display_name: displayName,
    device_id: deviceId
  });
  return body.session_token;
}

test('game rounds sync idempotently and reject malformed rounds', async (t) => {
  const { baseUrl } = await startServer(t);
  const good = round();
  const first = await post(`${baseUrl}/v1/games/rounds`, {
    device_id: 'device_g',
    rounds: [good, round({ mode: 'unknown' }), round({ client_round_id: '' })]
  });
  assert.equal(first.status, 200);
  assert.deepEqual(first.body.accepted_round_ids, [good.client_round_id]);
  assert.deepEqual(
    first.body.rejected_rounds.map((r) => r.reason),
    ['unknown_mode', 'missing_client_round_id']
  );

  const retry = await post(`${baseUrl}/v1/games/rounds`, { device_id: 'device_g', rounds: [good] });
  assert.deepEqual(retry.body.accepted_round_ids, []);
  assert.deepEqual(retry.body.duplicates, [good.client_round_id]);

  const empty = await post(`${baseUrl}/v1/games/rounds`, { device_id: 'device_g', rounds: [] });
  assert.equal(empty.status, 400);
});

test('leaderboard requires a session and ranks the best eligible round per user', async (t) => {
  const { baseUrl } = await startServer(t);
  const anonymous = await call(`${baseUrl}/v1/games/leaderboard?game=word_blaster&mode=classic`);
  assert.equal(anonymous.status, 401);

  const lan = await register(baseUrl, 'lan@example.com', 'device_lan', 'Lan');
  const minh = await register(baseUrl, 'minh.nguyen@example.com', 'device_minh');
  const auth = (token) => ({ authorization: `Bearer ${token}` });

  await post(`${baseUrl}/v1/games/rounds`, { device_id: 'device_lan', rounds: [round({ score: 3000 }), round({ score: 5000 })] }, auth(lan));
  await post(`${baseUrl}/v1/games/rounds`, { device_id: 'device_minh', rounds: [round({ score: 4000 })] }, auth(minh));
  // Implausible: far more points than 3 correct answers allow.
  await post(
    `${baseUrl}/v1/games/rounds`,
    { device_id: 'device_minh', rounds: [round({ score: 999_999, correct_count: 3, answered_count: 3 })] },
    auth(minh)
  );
  // Different mode is a separate board.
  await post(`${baseUrl}/v1/games/rounds`, { device_id: 'device_minh', rounds: [round({ mode: 'reverse', score: 9000 })] }, auth(minh));

  const board = await call(`${baseUrl}/v1/games/leaderboard?game=word_blaster&mode=classic`, { headers: auth(minh) });
  assert.equal(board.status, 200);
  assert.deepEqual(
    board.body.entries.map((e) => [e.rank, e.display_name, e.score, e.is_me]),
    [
      [1, 'Lan', 5000, false],
      [2, 'mi***', 4000, true]
    ]
  );
  assert.equal(board.body.me.rank, 2);

  const badMode = await call(`${baseUrl}/v1/games/leaderboard?game=word_blaster&mode=nope`, { headers: auth(minh) });
  assert.equal(badMode.status, 400);
});

test('rounds played before sign-in are claimed by the account', async (t) => {
  const { baseUrl } = await startServer(t);
  await post(`${baseUrl}/v1/games/rounds`, { device_id: 'device_claim', rounds: [round({ score: 4200 })] });
  const token = await register(baseUrl, 'claim@example.com', 'device_claim', 'Claimer');
  const board = await call(`${baseUrl}/v1/games/leaderboard?game=word_blaster&mode=classic`, {
    headers: { authorization: `Bearer ${token}` }
  });
  assert.equal(board.body.me.score, 4200);
});

test('admin games summary reports rounds, accuracy and game reviews', async (t) => {
  const { store, baseUrl } = await startServer(t);
  await post(`${baseUrl}/v1/games/rounds`, {
    device_id: 'device_s',
    rounds: [round({ correct_count: 9, answered_count: 10 }), round({ correct_count: 4, answered_count: 10, score: 800 })]
  });
  const word = store.insertWord({
    term: 'reliable',
    language: 'en',
    meaning_vi: 'đáng tin cậy',
    part_of_speech: 'adjective',
    ipa: '/x/',
    vietnamese_pronunciation: 'x',
    example: 'x',
    example_vi: 'x',
    difficulty: 'A1',
    topics: []
  }).word;
  await post(`${baseUrl}/v1/study-events/sync`, {
    device_id: 'device_s',
    events: [
      {
        client_event_id: 'evt_game_1',
        server_word_id: word.id,
        rating: 'hard',
        occurred_at: new Date().toISOString(),
        source: 'game_word_blaster'
      }
    ]
  });

  const denied = await call(`${baseUrl}/v1/admin/games/summary`);
  assert.equal(denied.status, 403);
  const summary = await call(`${baseUrl}/v1/admin/games/summary?days=7`, {
    headers: { 'x-expat8-admin-token': 'admin-token' }
  });
  assert.equal(summary.status, 200);
  assert.equal(summary.body.total_rounds, 2);
  assert.equal(summary.body.players, 1);
  assert.equal(summary.body.words_reviewed_via_games, 1);
  assert.equal(summary.body.accuracy_buckets.from_85, 1);
  assert.equal(summary.body.accuracy_buckets.under_50, 1);
});

test('game-sourced study events never change proficiency', () => {
  const store = new WordStore({ seed: false });
  const word = store.insertWord({
    term: 'brave',
    language: 'en',
    meaning_vi: 'dũng cảm',
    part_of_speech: 'adjective',
    ipa: '/x/',
    vietnamese_pronunciation: 'x',
    example: 'x',
    example_vi: 'x',
    difficulty: 'A1',
    topics: []
  }).word;
  const rated = (id, rating, source) => ({
    client_event_id: id,
    server_word_id: word.id,
    rating,
    occurred_at: `2026-09-28T08:${String(id.length + Number(id.slice(-1))).padStart(2, '0')}:00.000Z`,
    ...(source ? { source } : {})
  });
  store.syncStudyEvents({
    deviceId: 'device_p',
    events: Array.from({ length: 6 }, (_, i) => rated(`game_hard_${i}`, 'hard', 'game_word_blaster'))
  });
  assert.equal(store.getProficiency({ deviceId: 'device_p' }).level, 'A1');
  const stored = [...store.studyEventsByClientId.values()][0];
  assert.equal(stored.source, 'game_word_blaster');

  // Unknown or malformed sources are dropped, not stored.
  store.syncStudyEvents({ deviceId: 'device_p', events: [rated('evt_bad_source_1', 'easy', 'DROP TABLE')] });
  assert.equal(store.studyEventsByClientId.get('evt_bad_source_1').source, null);
});

test('plausibility and ranking helpers', () => {
  const normalized = normalizeGameRound(round({ score: 100, correct_count: 1, answered_count: 1, duration_ms: 5000, best_combo: 1 }));
  assert.equal(isPlausibleGameRound(normalized), true);
  assert.equal(isPlausibleGameRound({ ...normalized, correct_count: 2 }), false, 'correct > answered');
  assert.equal(isPlausibleGameRound({ ...normalized, duration_ms: 100 }), false, 'too fast');
  assert.equal(isPlausibleGameRound({ ...normalized, score: 901 }), false, 'too many points');
  assert.equal(isPlausibleGameRound({ ...normalized, wave: 5, score: 1900 }), true, 'boss bonus allowed');

  const ranked = rankLeaderboard(
    [
      { user_id: 'a', display_name: 'A', score: 10, correct_count: 1, answered_count: 2, best_combo: 1, completed_at: '2' },
      { user_id: 'a', display_name: 'A', score: 30, correct_count: 1, answered_count: 1, best_combo: 1, completed_at: '3' },
      { user_id: 'b', display_name: 'B', score: 30, correct_count: 1, answered_count: 1, best_combo: 1, completed_at: '1' }
    ],
    { userId: 'a' }
  );
  assert.deepEqual(ranked.entries.map((e) => e.display_name), ['B', 'A']);
  assert.equal(ranked.me.rank, 2);
});
