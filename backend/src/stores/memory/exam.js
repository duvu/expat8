// In-memory exam sessions, attempts and certificates.

import crypto from 'node:crypto';

import { createId } from '../../ids.js';
import {
  EXAM_MIN_SOURCE_WORDS,
  buildExamQuestions,
  examExpiresAt,
  pickExamSourceWords,
  scoreExam,
  toExamAttemptPayload,
  toExamSessionPayload,
  validateExamSubmission
} from '../../domain/exam.js';
import { collectTopics } from '../../domain/vocabulary.js';

export class MemoryExamMethods {
  /**
   * Returns distinct, normalized topics for which the user has studied at
   * least one word in the given language, sorted alphabetically.
   */
  examTopics({ userId, language = 'en' }) {
    return collectTopics(studiedWords(this, { userId, language }).map((word) => word.topics));
  }

  /**
   * Generates a new exam session with MCQ questions.
   * Returns { error: 'INSUFFICIENT_WORDS', found } when fewer than 5 source
   * words exist for the requested language, otherwise returns the full session
   * payload.
   */
  startExamSession({ userId, language = 'en', now = new Date().toISOString(), sessionTtlMs = 7200000 }) {
    const studied = studiedWords(this, { userId, language });
    if (studied.length < EXAM_MIN_SOURCE_WORDS) {
      return { error: 'INSUFFICIENT_WORDS', found: studied.length };
    }

    const sourceWords = pickExamSourceWords(studied);
    const sourceIds = new Set(sourceWords.map((w) => w.id));
    const pool = [...this.words.values()].filter((w) => w.language === language && !sourceIds.has(w.id));

    const sessionId = createId('exam_sess');
    const expiresAt = examExpiresAt(now, sessionTtlMs);
    this.examSessionsById.set(sessionId, {
      id: sessionId,
      user_id: userId,
      topic: 'language',
      language,
      difficulty_level: null,
      created_at: now,
      expires_at: expiresAt,
      submitted_at: null
    });

    const questions = buildExamQuestions({ sessionId, sourceWords, pool, now });
    this.examQuestionsBySessionId.set(sessionId, questions);
    return toExamSessionPayload({ sessionId, language, expiresAt, questions });
  }

  /**
   * Submits answers for an exam session.
   * Returns error objects for known failure modes, or the full result payload.
   *
   * When [localAttemptId] is provided and the session has already been
   * submitted with the same id, the call is treated as an idempotent retry
   * and the existing attempt data is returned instead of ALREADY_SUBMITTED.
   */
  submitExamSession({
    sessionId,
    userId,
    answers,
    localAttemptId = null,
    now = new Date().toISOString(),
    passPct = 70,
    disclaimer = ''
  }) {
    const session = this.examSessionsById.get(sessionId);
    if (!session) {
      return { error: 'NOT_FOUND' };
    }
    if (session.submitted_at) {
      // Idempotent retry: if the caller provided the same local_attempt_id
      // that was recorded on first submission, return the existing result.
      const existing =
        localAttemptId !== null && session.local_attempt_id === localAttemptId
          ? this.examAttemptsBySessionId.get(sessionId)
          : null;
      if (!existing) {
        return { error: 'ALREADY_SUBMITTED' };
      }
      return toExamAttemptPayload({
        attemptId: existing.id,
        sessionId,
        session: existing,
        score: {
          totalQuestions: existing.total_questions,
          correctCount: existing.correct_count,
          scorePct: existing.score_pct,
          passed: existing.passed === 1
        },
        certificateId: existing.certificate_id ?? null,
        createdAt: existing.created_at
      });
    }
    const questions = this.examQuestionsBySessionId.get(sessionId) ?? [];
    const invalid = validateExamSubmission({ session, questions, answers, now });
    if (invalid) {
      return invalid;
    }

    const score = scoreExam({ questions, answers, passPct });
    session.submitted_at = now;
    if (localAttemptId !== null) {
      session.local_attempt_id = localAttemptId;
    }

    const attemptId = createId('exam_att');
    const attempt = {
      id: attemptId,
      session_id: sessionId,
      user_id: userId,
      topic: session.topic,
      language: session.language,
      difficulty_level: session.difficulty_level,
      total_questions: score.totalQuestions,
      correct_count: score.correctCount,
      score_pct: score.scorePct,
      passed: score.passed ? 1 : 0,
      created_at: now
    };
    this.examAttemptsById.set(attemptId, attempt);
    this.examAttemptsBySessionId.set(sessionId, attempt);

    let certificateId = null;
    if (score.passed) {
      certificateId = crypto.randomUUID();
      this.examCertificatesById.set(certificateId, {
        id: certificateId,
        attempt_id: attemptId,
        user_id: userId,
        topic: session.topic,
        language: session.language,
        difficulty_level: session.difficulty_level,
        score_pct: score.scorePct,
        issued_at: now,
        disclaimer
      });
    }

    return toExamAttemptPayload({ attemptId, sessionId, session, score, certificateId, createdAt: now });
  }

  /**
   * Returns paginated exam attempt history for a user, newest first.
   */
  getExamResults({ userId, page = 1, limit = 20 }) {
    const all = [...this.examAttemptsById.values()]
      .filter((a) => a.user_id === userId)
      .sort((a, b) => b.created_at.localeCompare(a.created_at));

    const total = all.length;
    const offset = (page - 1) * limit;
    const items = all.slice(offset, offset + limit).map((a) => {
      const cert = [...this.examCertificatesById.values()].find((c) => c.attempt_id === a.id);
      return {
        attempt_id: a.id,
        topic: a.topic,
        language: a.language,
        difficulty_level: a.difficulty_level,
        score_pct: a.score_pct,
        passed: a.passed === 1,
        created_at: a.created_at,
        certificate_id: cert?.id ?? null
      };
    });

    return { items, total, page, limit };
  }

  /**
   * Returns a certificate by ID without user PII.
   * This is the public-facing endpoint response.
   */
  getExamCertificate({ id }) {
    const cert = this.examCertificatesById.get(id);
    if (!cert) {
      return null;
    }
    return {
      certificate_id: cert.id,
      topic: cert.topic,
      language: cert.language,
      difficulty_level: cert.difficulty_level,
      score_pct: cert.score_pct,
      issued_at: cert.issued_at,
      disclaimer: cert.disclaimer
    };
  }
}

// Distinct words the user has studied in the language.
function studiedWords(store, { userId, language }) {
  const words = new Map();
  for (const state of store.wordStatesByOwnerWord.values()) {
    const word = state.user_id === userId && state.language === language ? store.words.get(state.word_id) : null;
    if (word) {
      words.set(word.id, word);
    }
  }
  return [...words.values()];
}
