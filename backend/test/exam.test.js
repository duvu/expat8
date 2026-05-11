import assert from 'node:assert/strict';
import test from 'node:test';

import { WordStore, selectDistractors, shuffleArray, shuffleChoices, toApiWord } from '../src/word_store.js';

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

/** Seed a store with N language-matched words + distractors and return userId. */
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
  const result = store.startExamSession({ userId, language: 'en' });
  assert.equal(result.error, 'INSUFFICIENT_WORDS');
  assert.equal(result.found, 3);
});

test('startExamSession returns full session when 5+ source words are available', () => {
  const store = makeStore();
  const userId = seedExamFixture(store, { sourceCount: 7, distractorCount: 6 });

  const result = store.startExamSession({ userId, language: 'en' });

  assert.ok(result.session_id, 'session_id should be present');
  assert.equal(result.topic, 'language');
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
  const result = store.startExamSession({ userId, language: 'en' });
  assert.ok(result.question_count <= 20);
});

test('startExamSession question response does not expose correct_index', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const result = store.startExamSession({ userId, language: 'en' });
  for (const q of result.questions) {
    assert.ok(!('correct_index' in q), 'correct_index must not be in public question payload');
    assert.ok(Array.isArray(q.choices), 'choices should be an array');
    assert.equal(q.choices.length, 4, 'each question should have 4 choices');
  }
});

test('startExamSession stores questions internally', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const result = store.startExamSession({ userId, language: 'en' });
  const stored = store.examQuestionsBySessionId.get(result.session_id);
  assert.ok(stored, 'questions should be stored internally');
  assert.equal(stored.length, result.question_count);
  assert.ok(typeof stored[0].correct_index === 'number');
});

// ─── 5.5 submitExamSession ──────────────────────────────────────────────────

function runExamAndGetCorrectAnswers(store, userId) {
  const session = store.startExamSession({ userId, language: 'en' });
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

test('submitExamSession is idempotent when same local_attempt_id is provided', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);
  const localAttemptId = 'local-uuid-1234';

  const first = store.submitExamSession({
    sessionId: session.session_id, userId, answers: correctAnswers, localAttemptId
  });
  assert.ok(!first.error, 'first submission should succeed');

  // Retry with the same local_attempt_id — should return the existing result
  const retry = store.submitExamSession({
    sessionId: session.session_id, userId, answers: correctAnswers, localAttemptId
  });
  assert.ok(!retry.error, `retry should succeed idempotently, got: ${retry.error}`);
  assert.equal(retry.attempt_id, first.attempt_id, 'retry must return the same attempt');
  assert.equal(retry.score_pct, first.score_pct, 'retry must return the same score');
});

test('submitExamSession returns ALREADY_SUBMITTED when different local_attempt_id is used', () => {
  const store = makeStore();
  const userId = seedExamFixture(store);
  const { session, correctAnswers } = runExamAndGetCorrectAnswers(store, userId);

  store.submitExamSession({
    sessionId: session.session_id, userId, answers: correctAnswers, localAttemptId: 'id-a'
  });
  const second = store.submitExamSession({
    sessionId: session.session_id, userId, answers: correctAnswers, localAttemptId: 'id-b'
  });

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

// ─── Language isolation ──────────────────────────────────────────────────────

test('startExamSession English exam never contains Chinese words', () => {
  const store = makeStore();
  const userId = 'user_lang_en';
  // Add English source words
  for (let i = 0; i < 7; i++) {
    addWord(store, { id: `en_src_${i}`, term: `hello${i}`, language: 'en' });
    addWordState(store, { userId, wordId: `en_src_${i}`, language: 'en' });
  }
  // Add Chinese distractors (must never appear in English exam)
  for (let i = 0; i < 6; i++) {
    addWord(store, { id: `zh_dist_${i}`, term: `你好${i}`, language: 'zh' });
  }

  const result = store.startExamSession({ userId, language: 'en' });
  assert.ok(!result.error, `unexpected error: ${result.error}`);

  for (const q of result.questions) {
    // The prompt word is from the English pool
    const promptWord = store.words.get(
      [...store.words.values()].find((w) => w.term === q.prompt_word)?.id ?? ''
    );
    assert.equal(promptWord?.language ?? 'en', 'en', `prompt_word "${q.prompt_word}" must be English`);
    // All choices are Vietnamese meanings of English words (no cross-language leak)
    // The internal question stores the word; verify via word lookup
    const question = store.examQuestionsBySessionId
      .get(result.session_id)
      ?.find((iq) => iq.ordinal === q.ordinal);
    assert.ok(question, 'internal question must exist');
    const srcWord = store.words.get(question.word_id);
    assert.equal(srcWord?.language, 'en', `source word for question ${q.ordinal} must be English`);
  }
});

test('startExamSession Chinese exam never contains English words', () => {
  const store = makeStore();
  const userId = 'user_lang_zh';
  // Add Chinese source words
  for (let i = 0; i < 7; i++) {
    addWord(store, { id: `zh_src_${i}`, term: `汉字${i}`, language: 'zh' });
    addWordState(store, { userId, wordId: `zh_src_${i}`, language: 'zh' });
  }
  // Add English distractors (must never appear in Chinese exam)
  for (let i = 0; i < 6; i++) {
    addWord(store, { id: `en_dist_${i}`, term: `word${i}`, language: 'en' });
  }

  const result = store.startExamSession({ userId, language: 'zh' });
  assert.ok(!result.error, `unexpected error: ${result.error}`);

  for (const q of result.questions) {
    const question = store.examQuestionsBySessionId
      .get(result.session_id)
      ?.find((iq) => iq.ordinal === q.ordinal);
    assert.ok(question, 'internal question must exist');
    const srcWord = store.words.get(question.word_id);
    assert.equal(srcWord?.language, 'zh', `source word for question ${q.ordinal} must be Chinese`);
  }
});

// ─── 4.1–4.5  dual question types + word fields ─────────────────────────────

function addWordWithExample(store, { id, term, language = 'en', example = '', entry_type = 'word', explanation = '' } = {}) {
  store.words.set(id, {
    id,
    term,
    normalized_term: term.toLowerCase(),
    language,
    meaning_vi: `meaning of ${term}`,
    part_of_speech: '',
    ipa: '',
    vietnamese_pronunciation: '',
    example,
    example_vi: '',
    difficulty: 'B1',
    topics: [],
    generation_source: 'test',
    entry_type,
    explanation,
    created_at: '2026-01-01T00:00:00.000Z',
    updated_at: '2026-01-01T00:00:00.000Z'
  });
}

test('4.1 startExamSession assigns meaning_choice when example is empty', () => {
  const store = makeStore();
  const userId = 'user_41';
  for (let i = 0; i < 8; i++) {
    addWordWithExample(store, { id: `w41_${i}`, term: `word${i}`, example: '' });
    addWordState(store, { userId, wordId: `w41_${i}` });
  }
  const result = store.startExamSession({ userId, language: 'en' });
  assert.ok(!result.error);
  for (const q of result.questions) {
    assert.equal(q.question_type, 'meaning_choice', `question ${q.ordinal} must be meaning_choice when example is empty`);
    assert.equal(q.sentence, undefined);
    assert.equal(q.highlight, undefined);
  }
});

test('4.2 startExamSession assigns sentence_context with sentence+highlight when example is non-empty', () => {
  const store = makeStore();
  const userId = 'user_42';
  for (let i = 0; i < 8; i++) {
    addWordWithExample(store, { id: `w42_${i}`, term: `word${i}`, example: `Example sentence for word${i}.` });
    addWordState(store, { userId, wordId: `w42_${i}` });
  }

  // Run many times — 50/50 means P(no sentence_context in 20 runs) ≈ (0.5)^20 ≈ 1e-6
  let foundSentenceContext = false;
  for (let attempt = 0; attempt < 20 && !foundSentenceContext; attempt++) {
    const result = store.startExamSession({ userId, language: 'en' });
    assert.ok(!result.error);
    for (const q of result.questions) {
      if (q.question_type === 'sentence_context') {
        foundSentenceContext = true;
        assert.ok(typeof q.sentence === 'string' && q.sentence.length > 0, 'sentence must be non-empty string');
        assert.ok(typeof q.highlight === 'string' && q.highlight.length > 0, 'highlight must be non-empty string');
        assert.equal(q.highlight, q.prompt_word, 'highlight must equal prompt_word (the term)');
      }
    }
  }
  assert.ok(foundSentenceContext, 'at least one sentence_context question must appear across 20 session creations');
});

test('4.3 startExamSession: words without example are always meaning_choice in a mixed pool', () => {
  const store = makeStore();
  const userId = 'user_43';
  // 5 words with example, 5 without
  for (let i = 0; i < 5; i++) {
    addWordWithExample(store, { id: `w43_ex_${i}`, term: `withEx${i}`, example: `Sentence for withEx${i}.` });
    addWordState(store, { userId, wordId: `w43_ex_${i}` });
  }
  for (let i = 0; i < 5; i++) {
    addWordWithExample(store, { id: `w43_no_${i}`, term: `noEx${i}`, example: '' });
    addWordState(store, { userId, wordId: `w43_no_${i}` });
  }

  // Run several times to verify no-example words never get sentence_context
  for (let attempt = 0; attempt < 10; attempt++) {
    const result = store.startExamSession({ userId, language: 'en' });
    assert.ok(!result.error);
    const noExTerms = new Set(['noEx0', 'noEx1', 'noEx2', 'noEx3', 'noEx4']);
    for (const q of result.questions) {
      if (noExTerms.has(q.prompt_word)) {
        assert.equal(q.question_type, 'meaning_choice', `word without example must be meaning_choice, got ${q.question_type}`);
      }
    }
  }
});

test('4.4 toApiWord includes entry_type and explanation in response shape', () => {
  const word = {
    id: 'w_test',
    term: 'break the ice',
    language: 'en',
    meaning_vi: 'phá vỡ bầu không khí ngại ngùng',
    part_of_speech: '',
    ipa: '',
    vietnamese_pronunciation: '',
    example: 'He told a joke to break the ice.',
    example_vi: '',
    difficulty: 'B1',
    topics: [],
    entry_type: 'phrase',
    explanation: 'Dùng khi muốn tạo không khí thoải mái.',
    created_at: '2026-01-01T00:00:00.000Z',
    updated_at: '2026-01-01T00:00:00.000Z'
  };
  const api = toApiWord(word);
  assert.equal(api.entry_type, 'phrase');
  assert.equal(api.explanation, 'Dùng khi muốn tạo không khí thoải mái.');
});

test('4.5 phrase/idiom inserted with empty ipa and part_of_speech is accepted without error', () => {
  const store = makeStore();
  const result = store.insertWord({
    term: 'kick the bucket',
    language: 'en-idioms',
    meaning_vi: 'chết',
    part_of_speech: '',
    ipa: '',
    vietnamese_pronunciation: '',
    example: 'The old man finally kicked the bucket.',
    example_vi: '',
    difficulty: 'B2',
    topics: [],
    entry_type: 'idiom',
    explanation: 'Cụm từ thông tục để nói ai đó qua đời.',
  });
  assert.ok(!result.error, `expected no error, got: ${result.error}`);
  assert.ok(result.word?.id, 'inserted word must have an id');
  const stored = store.words.get(result.word.id);
  assert.equal(stored.entry_type, 'idiom');
  assert.equal(stored.ipa, '');
  assert.equal(stored.part_of_speech, '');
});
