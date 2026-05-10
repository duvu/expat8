import assert from 'node:assert/strict';
import test from 'node:test';

import { WordStore, selectDistractors, shuffleArray, shuffleChoices } from '../src/word_store.js';

// ─── helpers ────────────────────────────────────────────────────────────────

function makeStore() {
  return new WordStore({ seed: false });
}

function addWord(store, { id, term, language = 'en', difficulty = 'B1', topics = [], meaning_vi = null } = {}) {
  store.words.set(id, {
    id,
    term,
    normalized_term: term.toLowerCase(),
    language,
    meaning_vi: meaning_vi ?? `meaning of ${term}`,
    part_of_speech: null,
    ipa: null,
    vietnamese_pronunciation: null,
    example: null,
    example_vi: null,
    difficulty,
    topics,
    generation_source: 'test',
    created_at: '2026-01-01T00:00:00.000Z',
    updated_at: '2026-01-01T00:00:00.000Z'
  });
}

/** Directly inject a user word state (bypasses SRS logic for speed). */
function addWordState(store, { userId, wordId, language = 'en' }) {
  const key = `user:${userId}:word:${wordId}`;
  store.wordStatesByOwnerWord.set(key, {
    user_id: userId,
    device_id: null,
    word_id: wordId,
    language,
    status: 'review',
    last_rating: 'hard',
    last_studied_at: '2026-01-01T00:00:00.000Z',
    next_review_at: null,
    updated_at: '2026-01-01T00:00:00.000Z'
  });
}

/** Seed a store with N topic-matched words + distractors and return userId. */
function seedExamFixture(store, { topic = 'work', language = 'en', sourceCount = 7, distractorCount = 6 } = {}) {
  const userId = 'user_exam_1';

  for (let i = 0; i < sourceCount; i++) {
    addWord(store, { id: `src_${i}`, term: `src${i}`, language, topics: [topic], difficulty: 'B1' });
    addWordState(store, { userId, wordId: `src_${i}`, language });
  }
  for (let i = 0; i < distractorCount; i++) {
    addWord(store, { id: `dist_${i}`, term: `dist${i}`, language, topics: ['other'], difficulty: 'B1' });
  }
  return userId;
}

// ─── 3.2 examTopics ─────────────────────────────────────────────────────────

test('examTopics returns empty array when user has no studied words', () => {
  const store = makeStore();
  const topics = store.examTopics({ userId: 'nobody', language: 'en' });
  assert.deepEqual(topics, []);
});

test('examTopics returns distinct normalised topics for the user and language', () => {
  const store = makeStore();
  const userId = 'user_topics_1';
  addWord(store, { id: 'w1', term: 'alpha', language: 'en', topics: ['Work', 'Travel'] });
  addWord(store, { id: 'w2', term: 'beta', language: 'en', topics: ['work', 'people'] }); // 'work' duplicate
  addWord(store, { id: 'w3', term: 'gamma', language: 'vi', topics: ['du lich'] }); // different language
  addWordState(store, { userId, wordId: 'w1', language: 'en' });
  addWordState(store, { userId, wordId: 'w2', language: 'en' });
  addWordState(store, { userId, wordId: 'w3', language: 'vi' });

  const enTopics = store.examTopics({ userId, language: 'en' });
  const viTopics = store.examTopics({ userId, language: 'vi' });

  assert.deepEqual(enTopics, ['people', 'travel', 'work']); // sorted, lowercase, deduped
  assert.deepEqual(viTopics, ['du lich']);
});

test('examTopics does not expose other users topics', () => {
  const store = makeStore();
  addWord(store, { id: 'w1', term: 'alpha', language: 'en', topics: ['food'] });
  addWordState(store, { userId: 'user_a', wordId: 'w1', language: 'en' });

  const topics = store.examTopics({ userId: 'user_b', language: 'en' });
  assert.deepEqual(topics, []);
});

// ─── 4.6 startExamSession ───────────────────────────────────────────────────

test('startExamSession returns INSUFFICIENT_WORDS when fewer than 5 source words', () => {
  const store = makeStore();
  const userId = 'user_few_words';
  for (let i = 0; i < 3; i++) {
    addWord(store, { id: `fw_${i}`, term: `fw${i}`, language: 'en', topics: ['science'] });
    addWordState(store, { userId, wordId: `fw_${i}`, language: 'en' });
  }
  const result = store.startExamSession({ userId, topic: 'science', language: 'en' });
  assert.equal(result.error, 'INSUFFICIENT_WORDS');
  assert.equal(result.found, 3);
});

test('startExamSession returns full session when 5+ source words are available', () => {
  const store = makeStore();
  const userId = seedExamFixture(store, { sourceCount: 7, distractorCount: 6 });

  const result = store.startExamSession({ userId, topic: 'work', language: 'en' });

  assert.ok(result.session_id, 'session_id should be present');
  assert.equal(result.topic, 'work');
  assert.equal(result.language, 'en');
  assert.ok(result.question_count >= 5);
  assert.equal(result.questions.length, result.question_count);
});

test('startExamSession caps questions at 20', () => {
  const store = makeStore();
  const userId = 'user_big';
  for (let i = 0; i < 30; i++) {
    addWord(store, { id: `big_${i}`, term: `big${i}`, language: 'en', topics: ['travel'] });
    addWordState(store, { userId, wordId: `big_${i}`, language: 'en' });
  }
  for (let i = 0; i < 10; i++) {
    addWord(store, { id: `bigdist_${i}`, term: `bigdist${i}`, language: 'en', topics: ['other'] });
  }
  const result = store.startExamSession({ userId, topic: 'travel', language: 'en' });
  assert.ok(result.question_count <= 20);
});

test('startExamSession question response does not expose correct_index', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const result = store.startExamSession({ userId, topic: 'work', language: 'en' });
  for (const q of result.questions) {
    assert.ok(!('correct_index' in q), 'correct_index must not be in public question payload');
    assert.ok(Array.isArray(q.choices), 'choices should be an array');
    assert.equal(q.choices.length, 4, 'each question should have 4 choices');
  }
});

test('startExamSession stores questions internally', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const result = store.startExamSession({ userId, topic: 'work', language: 'en' });
  const stored = store.examQuestionsBySessionId.get(result.session_id);
  assert.ok(stored, 'questions should be stored internally');
  assert.equal(stored.length, result.question_count);
  assert.ok(typeof stored[0].correct_index === 'number');
});

// ─── 5.5 submitExamSession ──────────────────────────────────────────────────

function runExamAndGetCorrectAnswers(store, userId, topic = 'work') {
  const session = store.startExamSession({ userId, topic, language: 'en' });
  const internal = store.examQuestionsBySessionId.get(session.session_id);
  const correctAnswers = internal.map((q) => q.correct_index);
  const wrongAnswers = internal.map((q) => (q.correct_index === 0 ? 1 : 0));
  return { session, correctAnswers, wrongAnswers };
}

test('submitExamSession with all correct answers creates a certificate (passed)', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);

  const result = store.submitExamSession({
    sessionId: session.session_id,
    userId,
    answers: correctAnswers,
    disclaimer: 'test disclaimer'
  });

  assert.equal(result.passed, true);
  assert.ok(result.certificate_id, 'should have certificate_id on pass');
  assert.equal(result.score_pct, 100);
  const cert = store.examCertificatesById.get(result.certificate_id);
  assert.ok(cert, 'certificate should be in store');
});

test('submitExamSession with all wrong answers does not create a certificate (failed)', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, wrongAnswers } = runExamAndGetCorrectAnswers(store, userId);

  const result = store.submitExamSession({
    sessionId: session.session_id,
    userId,
    answers: wrongAnswers
  });

  assert.equal(result.passed, false);
  assert.equal(result.certificate_id, null);
  assert.equal(store.examCertificatesById.size, 0);
});

test('submitExamSession returns 409 on duplicate submission', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);

  store.submitExamSession({ sessionId: session.session_id, userId, answers: correctAnswers });
  const second = store.submitExamSession({ sessionId: session.session_id, userId, answers: correctAnswers });

  assert.equal(second.error, 'ALREADY_SUBMITTED');
});

test('submitExamSession returns NOT_FOUND for unknown session', () => {
  const store = makeStore();
  const result = store.submitExamSession({
    sessionId: 'unknown_session',
    userId: 'user_1',
    answers: []
  });
  assert.equal(result.error, 'NOT_FOUND');
});

test('submitExamSession returns SESSION_EXPIRED for stale session', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);

  const futureNow = new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString(); // 3 hours later
  const result = store.submitExamSession({
    sessionId: session.session_id,
    userId,
    answers: correctAnswers,
    now: futureNow
  });
  assert.equal(result.error, 'SESSION_EXPIRED');
});

test('submitExamSession returns ANSWER_COUNT_MISMATCH when answer count differs', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session } = runExamAndGetCorrectAnswers(store, userId);

  const result = store.submitExamSession({
    sessionId: session.session_id,
    userId,
    answers: [0] // wrong count
  });
  assert.equal(result.error, 'ANSWER_COUNT_MISMATCH');
  assert.ok(result.expected > 0);
});

test('submitExamSession does not modify wordStatesByOwnerWord (no SRS side-effects)', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);

  const statesBefore = new Map(store.wordStatesByOwnerWord);
  store.submitExamSession({ sessionId: session.session_id, userId, answers: correctAnswers });
  assert.equal(store.wordStatesByOwnerWord.size, statesBefore.size);
  for (const [k, v] of statesBefore) {
    assert.deepEqual(store.wordStatesByOwnerWord.get(k), v);
  }
});

// ─── 6.3 getExamResults ─────────────────────────────────────────────────────

test('getExamResults returns empty items for user with no attempts', () => {
  const store = makeStore();
  const result = store.getExamResults({ userId: 'nobody', page: 1, limit: 20 });
  assert.deepEqual(result.items, []);
  assert.equal(result.total, 0);
  assert.equal(result.page, 1);
  assert.equal(result.limit, 20);
});

test('getExamResults returns attempts newest first', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session: s1, correctAnswers: a1 } = runExamAndGetCorrectAnswers(store, userId);
  store.submitExamSession({ sessionId: s1.session_id, userId, answers: a1, now: '2026-01-01T10:00:00.000Z' });

  // Second attempt: insert separate session manually for timing control
  const userId2 = seedExamFixture(new WordStore({ seed: false })); // unused, just for clarity
  const { session: s2, wrongAnswers: a2 } = runExamAndGetCorrectAnswers(store, userId);
  store.submitExamSession({ sessionId: s2.session_id, userId, answers: a2, now: '2026-01-02T10:00:00.000Z' });

  const result = store.getExamResults({ userId, page: 1, limit: 20 });
  assert.equal(result.total, 2);
  // newest first: '2026-01-02' before '2026-01-01'
  assert.ok(result.items[0].created_at >= result.items[1].created_at);
});

test('getExamResults paginates correctly', () => {
  const store = makeStore();
  const userId = seedExamFixture(store, { sourceCount: 10, distractorCount: 5 });
  // Create 3 submissions
  for (let i = 0; i < 3; i++) {
    const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);
    store.submitExamSession({ sessionId: session.session_id, userId, answers: correctAnswers });
  }

  const page1 = store.getExamResults({ userId, page: 1, limit: 2 });
  const page2 = store.getExamResults({ userId, page: 2, limit: 2 });

  assert.equal(page1.items.length, 2);
  assert.equal(page1.total, 3);
  assert.equal(page2.items.length, 1);
  assert.equal(page2.total, 3);
});

// ─── 7.3 getExamCertificate ─────────────────────────────────────────────────

test('getExamCertificate returns null for unknown id', () => {
  const store = makeStore();
  assert.equal(store.getExamCertificate({ id: 'no-such-id' }), null);
});

test('getExamCertificate returns certificate without user PII', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);
  const result = store.submitExamSession({
    sessionId: session.session_id,
    userId,
    answers: correctAnswers,
    disclaimer: 'internal only'
  });
  assert.ok(result.certificate_id, 'exam must pass to get a certificate');

  const cert = store.getExamCertificate({ id: result.certificate_id });
  assert.ok(cert, 'certificate should be returned');
  assert.equal(cert.certificate_id, result.certificate_id);
  assert.ok(!('user_id' in cert), 'user_id must not be in public certificate');
  assert.equal(cert.disclaimer, 'internal only');
});

// ─── shuffleArray / selectDistractors ───────────────────────────────────────

test('shuffleArray returns all same elements in potentially different order', () => {
  const original = [1, 2, 3, 4, 5];
  const shuffled = shuffleArray(original);
  assert.deepEqual([...shuffled].sort((a, b) => a - b), original);
});

test('selectDistractors picks words from difficulty ±1 bucket when available', () => {
  const source = { id: 'src', difficulty: 'B1' };
  const pool = [
    { id: 'd1', difficulty: 'A2' }, // ±1 ok
    { id: 'd2', difficulty: 'B1' }, // exact
    { id: 'd3', difficulty: 'B2' }, // ±1 ok
    { id: 'd4', difficulty: 'C1' }, // too far
    { id: 'd5', difficulty: 'A1' }  // too far
  ];
  const result = selectDistractors({ source, pool, count: 3 });
  assert.equal(result.length, 3);
  // All chosen should be within ±1 of B1 (A2, B1, B2)
  const validDifficulties = new Set(['A2', 'B1', 'B2']);
  for (const d of result) {
    assert.ok(validDifficulties.has(d.difficulty), `${d.difficulty} is not within ±1 of B1`);
  }
});

test('selectDistractors falls back to full pool when near-difficulty pool is too small', () => {
  const source = { id: 'src', difficulty: 'B1' };
  const pool = [
    { id: 'd1', difficulty: 'C2' },
    { id: 'd2', difficulty: 'C2' },
    { id: 'd3', difficulty: 'C2' }
  ];
  const result = selectDistractors({ source, pool, count: 3 });
  assert.equal(result.length, 3);
});
