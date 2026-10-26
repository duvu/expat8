// PostgreSQL exam sessions, attempts and certificates.

import crypto from 'node:crypto';

import { createId } from '../../ids.js';
import {
  CERTIFICATE_DISCLAIMER,
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
import { withOptionalTransaction } from './transaction.js';

export class PostgresExamMethods {
  async examTopics({ userId, language = 'en' }) {
    const result = await this.pool.query(
      `SELECT DISTINCT w.topics_json
       FROM user_word_states uws
       JOIN words w ON w.id = uws.word_id
       WHERE uws.user_id = $1 AND uws.language = $2`,
      [userId, language]
    );
    return collectTopics(result.rows.map((row) => parseTopicsJson(row.topics_json)));
  }

  async startExamSession({ userId, language = 'en', now = new Date().toISOString(), sessionTtlMs = 7200000 }) {
    const expiresAt = examExpiresAt(now, sessionTtlMs);

    return withOptionalTransaction(this, async (client) => {
      // Find studied words for the active language.
      const sourceResult = await client.query(
        `SELECT w.id, w.term, w.meaning_vi, w.difficulty, w.topics_json, w.language, w.example, w.entry_type
         FROM user_word_states uws
         JOIN words w ON w.id = uws.word_id
         WHERE uws.user_id = $1 AND uws.language = $2`,
        [userId, language]
      );
      const studiedWords = sourceResult.rows;
      if (studiedWords.length < EXAM_MIN_SOURCE_WORDS) {
        return { error: 'INSUFFICIENT_WORDS', found: studiedWords.length };
      }

      const sourceWords = pickExamSourceWords(studiedWords);
      const sourceIds = new Set(sourceWords.map((w) => w.id));
      const distResult = await client.query(
        `SELECT id, term, meaning_vi, difficulty, example, entry_type FROM words WHERE language = $1`,
        [language]
      );
      const pool = distResult.rows.filter((w) => !sourceIds.has(w.id));

      const sessionId = createId('exam_sess');
      await client.query(
        `INSERT INTO exam_sessions (id, user_id, topic, language, difficulty_level, created_at, expires_at, submitted_at)
         VALUES ($1, $2, $3, $4, NULL, $5, $6, NULL)`,
        [sessionId, userId, 'language', language, now, expiresAt]
      );

      const questions = buildExamQuestions({ sessionId, sourceWords, pool, now });
      for (const question of questions) {
        await client.query(
          `INSERT INTO exam_questions (id, session_id, word_id, prompt_word, choices_json, correct_index, ordinal, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            question.id,
            question.session_id,
            question.word_id,
            question.prompt_word,
            question.choices_json,
            question.correct_index,
            question.ordinal,
            question.created_at
          ]
        );
      }
      return toExamSessionPayload({ sessionId, language, expiresAt, questions });
    });
  }

  async submitExamSession({ sessionId, userId, answers, now = new Date().toISOString(), passPct = 70 }) {
    return withOptionalTransaction(this, async (client) => {
      const sessResult = await client.query(`SELECT * FROM exam_sessions WHERE id = $1`, [sessionId]);
      if (sessResult.rows.length === 0) return { error: 'NOT_FOUND' };
      const session = sessResult.rows[0];
      if (session.submitted_at) return { error: 'ALREADY_SUBMITTED' };

      const qResult = await client.query(`SELECT * FROM exam_questions WHERE session_id = $1 ORDER BY ordinal`, [
        sessionId
      ]);
      const questions = qResult.rows;
      const invalid = validateExamSubmission({ session, questions, answers, now });
      if (invalid) {
        return invalid;
      }

      const score = scoreExam({ questions, answers, passPct });
      await client.query(`UPDATE exam_sessions SET submitted_at = $1 WHERE id = $2`, [now, sessionId]);

      const attemptId = createId('exam_att');
      await client.query(
        `INSERT INTO exam_attempts (id, session_id, user_id, topic, language, difficulty_level, total_questions, correct_count, score_pct, passed, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
        [
          attemptId,
          sessionId,
          userId,
          session.topic,
          session.language,
          session.difficulty_level,
          score.totalQuestions,
          score.correctCount,
          score.scorePct,
          score.passed ? 1 : 0,
          now
        ]
      );

      let certificateId = null;
      if (score.passed) {
        certificateId = crypto.randomUUID();
        await client.query(
          `INSERT INTO exam_certificates (id, attempt_id, user_id, topic, language, difficulty_level, score_pct, issued_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [certificateId, attemptId, userId, session.topic, session.language, session.difficulty_level, score.scorePct, now]
        );
      }

      return toExamAttemptPayload({ attemptId, sessionId, session, score, certificateId, createdAt: now });
    });
  }

  async getExamResults({ userId, page = 1, limit = 20 }) {
    const offset = (page - 1) * limit;
    const countResult = await this.pool.query(`SELECT COUNT(*) AS total FROM exam_attempts WHERE user_id = $1`, [
      userId
    ]);
    const total = Number(countResult.rows[0]?.total ?? 0);
    const itemsResult = await this.pool.query(
      `SELECT ea.id AS attempt_id, ea.topic, ea.language, ea.difficulty_level, ea.score_pct,
              ea.passed, ea.created_at, ec.id AS certificate_id
       FROM exam_attempts ea
       LEFT JOIN exam_certificates ec ON ec.attempt_id = ea.id
       WHERE ea.user_id = $1
       ORDER BY ea.created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );
    const items = itemsResult.rows.map((r) => ({
      attempt_id: r.attempt_id,
      topic: r.topic,
      language: r.language,
      difficulty_level: r.difficulty_level,
      score_pct: r.score_pct,
      passed: r.passed === 1 || r.passed === true,
      created_at: r.created_at,
      certificate_id: r.certificate_id ?? null
    }));
    return { items, total, page, limit };
  }

  async getExamCertificate({ id }) {
    const result = await this.pool.query(
      `SELECT id, topic, language, difficulty_level, score_pct, issued_at
       FROM exam_certificates WHERE id = $1`,
      [id]
    );
    if (result.rows.length === 0) return null;
    const r = result.rows[0];
    return {
      certificate_id: r.id,
      topic: r.topic,
      language: r.language,
      difficulty_level: r.difficulty_level,
      score_pct: r.score_pct,
      issued_at: r.issued_at,
      disclaimer: CERTIFICATE_DISCLAIMER
    };
  }
}

function parseTopicsJson(value) {
  try {
    return JSON.parse(value ?? '[]');
  } catch {
    return [];
  }
}
