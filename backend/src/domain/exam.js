// Exam rules shared by both stores: question generation, scoring and API shaping.

import { createId } from '../ids.js';

export const CERTIFICATE_DISCLAIMER =
  'This is an internal Expat8 completion certificate. It does not represent an official CEFR or HSK examination result.';

export const EXAM_MIN_SOURCE_WORDS = 5;
const EXAM_MAX_QUESTIONS = 20;
const DISTRACTOR_COUNT = 3;
const DIFFICULTY_ORDER = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6', 'HSK7'];

export function selectDistractors({ source, pool, count = DISTRACTOR_COUNT }) {
  const srcIdx = DIFFICULTY_ORDER.indexOf(source.difficulty ?? '');
  // Try same difficulty ±1 first
  const nearPool =
    srcIdx >= 0
      ? pool.filter((w) => {
          const idx = DIFFICULTY_ORDER.indexOf(w.difficulty ?? '');
          return idx >= 0 && Math.abs(idx - srcIdx) <= 1;
        })
      : [];
  const candidates = nearPool.length >= count ? nearPool : pool;
  return shuffleArray(candidates).slice(0, count);
}

export function shuffleArray(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Shuffles choices whose first entry is the correct one; returns the new correct index. */
function shuffleChoices(choices) {
  const shuffled = shuffleArray(choices.map((c, i) => ({ c, i })));
  const correctIndex = shuffled.findIndex((item) => item.i === 0);
  return { choices: shuffled.map((item) => item.c), correctIndex };
}

/** Up to 20 shuffled studied words to quiz on. */
export function pickExamSourceWords(studiedWords) {
  return shuffleArray(studiedWords).slice(0, EXAM_MAX_QUESTIONS);
}

/**
 * Multiple-choice questions for the source words. Distractors come from
 * `pool` (same-language words that are not quizzed). Words with an example
 * sentence are asked in sentence context half of the time.
 */
export function buildExamQuestions({ sessionId, sourceWords, pool, now }) {
  return sourceWords.map((src, ordinal) => {
    const distractors = selectDistractors({ source: src, pool, count: DISTRACTOR_COUNT });
    const correctMeaning = src.meaning_vi ?? src.term;
    const { choices, correctIndex } = shuffleChoices([correctMeaning, ...distractors.map((d) => d.meaning_vi ?? d.term)]);
    const hasExample = src.example && src.example.trim() !== '';
    const questionType = hasExample && Math.random() < 0.5 ? 'sentence_context' : 'meaning_choice';
    return {
      id: createId('exam_q'),
      session_id: sessionId,
      word_id: src.id,
      prompt_word: src.term,
      choices_json: JSON.stringify(choices),
      correct_index: correctIndex,
      ordinal,
      created_at: now,
      question_type: questionType,
      sentence: questionType === 'sentence_context' ? src.example : null,
      highlight: questionType === 'sentence_context' ? src.term : null
    };
  });
}

/** API payload of a started exam (correct answers are never sent). */
export function toExamSessionPayload({ sessionId, language, expiresAt, questions }) {
  return {
    session_id: sessionId,
    topic: 'language',
    language,
    question_count: questions.length,
    expires_at: expiresAt,
    questions: questions.map((q) => {
      const item = {
        question_id: q.id,
        ordinal: q.ordinal,
        prompt_word: q.prompt_word,
        choices: JSON.parse(q.choices_json),
        question_type: q.question_type
      };
      if (q.question_type === 'sentence_context') {
        item.sentence = q.sentence;
        item.highlight = q.highlight;
      }
      return item;
    })
  };
}

export function examExpiresAt(now, sessionTtlMs) {
  return new Date(new Date(now).getTime() + sessionTtlMs).toISOString();
}

/** Submission check before scoring; returns an error object or null. */
export function validateExamSubmission({ session, questions, answers, now }) {
  if (now > session.expires_at) {
    return { error: 'SESSION_EXPIRED' };
  }
  if (answers.length !== questions.length) {
    return { error: 'ANSWER_COUNT_MISMATCH', expected: questions.length, received: answers.length };
  }
  return null;
}

export function scoreExam({ questions, answers, passPct }) {
  const correctCount = questions.filter((question, index) => Number(answers[index]) === question.correct_index).length;
  const totalQuestions = questions.length;
  const scorePct = totalQuestions > 0 ? (correctCount / totalQuestions) * 100 : 0;
  return { totalQuestions, correctCount, scorePct, passed: scorePct >= passPct };
}

/** API payload of a submitted attempt. */
export function toExamAttemptPayload({ attemptId, sessionId, session, score, certificateId, createdAt }) {
  return {
    attempt_id: attemptId,
    session_id: sessionId,
    topic: session.topic,
    language: session.language,
    difficulty_level: session.difficulty_level,
    total_questions: score.totalQuestions,
    correct_count: score.correctCount,
    score_pct: score.scorePct,
    passed: score.passed,
    certificate_id: certificateId,
    created_at: createdAt
  };
}
