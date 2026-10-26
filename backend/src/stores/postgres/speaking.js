// PostgreSQL speaking events, weekly speaking summaries and speaking prompts.

import { createId } from '../../ids.js';
import { clampLimit } from '../../domain/pagination.js';
import {
  applySpeakingPromptPatch,
  isPromptMissingRequiredFields,
  normalizeSpeakingEvent,
  normalizeSpeakingPromptInput,
  normalizeWeekStart
} from '../../domain/speaking.js';
import { resolveEventKey } from '../../domain/study_events.js';

export class PostgresSpeakingMethods {
  async recordSpeakingEvent({ deviceId, event, language = 'en', userId = null }) {
    const eventKey = resolveEventKey(event);
    if (!eventKey) {
      throw new Error('missing_event_id');
    }
    const normalized = normalizeSpeakingEvent({ deviceId, event, language, userId, strict: this.strictAttemptId });
    const eventId = event.event_id ?? eventKey;
    const clientEventId = event.client_event_id ?? eventKey;
    const existing = await this.pool.query(
      `SELECT id FROM speaking_events
      WHERE event_id = $1 OR client_event_id = $2
      LIMIT 1`,
      [eventId, clientEventId]
    );
    if (existing.rows[0]) {
      return { eventId: existing.rows[0].id, idempotent: true };
    }
    const receivedAt = new Date().toISOString();
    const inserted = await this.pool.query(
      `INSERT INTO speaking_events (
        id,
        event_id,
        client_event_id,
        device_id,
        user_id,
        event_type,
        attempt_id,
        prompt_id,
        word_sense_id,
        server_word_id,
        duration_ms,
        retry_count,
        self_rating,
        language,
        occurred_at,
        received_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
      RETURNING id`,
      [
        createId('speaking_event'),
        eventId,
        clientEventId,
        normalized.device_id,
        normalized.user_id,
        normalized.event_type,
        normalized.attempt_id,
        normalized.prompt_id,
        normalized.word_sense_id,
        normalized.server_word_id,
        normalized.duration_ms,
        normalized.retry_count,
        normalized.self_rating,
        normalized.language,
        normalized.occurred_at,
        receivedAt
      ]
    );
    return { eventId: inserted.rows[0].id, idempotent: false };
  }

  async getSpeakingSummary({ deviceId, language = 'en', userId = null, weekStart = null }) {
    const start = normalizeWeekStart(weekStart);
    const result = userId
      ? await this.pool.query(
          `SELECT
            COUNT(*) FILTER (WHERE event_type = 'speaking_recorded')::int AS spoken_sentence_count,
            COUNT(*) FILTER (WHERE event_type = 'speaking_retried')::int AS retry_count,
            COALESCE(SUM(duration_ms) FILTER (WHERE event_type = 'speaking_recorded'), 0)::int AS approximate_duration_ms,
            COUNT(*) FILTER (WHERE self_rating = 'clear')::int AS clear_count,
            COUNT(*) FILTER (WHERE self_rating = 'hesitated')::int AS hesitated_count,
            COUNT(*) FILTER (WHERE self_rating = 'could_not_say')::int AS could_not_say_count,
            COUNT(*) FILTER (WHERE event_type = 'loop_completed')::int AS loop_completion_count,
            MAX(occurred_at) AS latest_activity_at
          FROM speaking_events
          WHERE user_id = $1 AND language = $2 AND occurred_at >= $3`,
          [userId, language, start]
        )
      : await this.pool.query(
          `SELECT
            COUNT(*) FILTER (WHERE event_type = 'speaking_recorded')::int AS spoken_sentence_count,
            COUNT(*) FILTER (WHERE event_type = 'speaking_retried')::int AS retry_count,
            COALESCE(SUM(duration_ms) FILTER (WHERE event_type = 'speaking_recorded'), 0)::int AS approximate_duration_ms,
            COUNT(*) FILTER (WHERE self_rating = 'clear')::int AS clear_count,
            COUNT(*) FILTER (WHERE self_rating = 'hesitated')::int AS hesitated_count,
            COUNT(*) FILTER (WHERE self_rating = 'could_not_say')::int AS could_not_say_count,
            COUNT(*) FILTER (WHERE event_type = 'loop_completed')::int AS loop_completion_count,
            MAX(occurred_at) AS latest_activity_at
          FROM speaking_events
          WHERE device_id = $1 AND user_id IS NULL AND language = $2 AND occurred_at >= $3`,
          [deviceId, language, start]
        );
    const row = result.rows[0] ?? {};
    return {
      device_id: deviceId,
      user_id: userId,
      language,
      week_start: start.slice(0, 10),
      spoken_sentence_count: Number(row.spoken_sentence_count ?? 0),
      recording_count: Number(row.spoken_sentence_count ?? 0),
      retry_count: Number(row.retry_count ?? 0),
      approximate_duration_ms: Number(row.approximate_duration_ms ?? 0),
      loop_completion_count: Number(row.loop_completion_count ?? 0),
      self_rating_counts: {
        clear: Number(row.clear_count ?? 0),
        hesitated: Number(row.hesitated_count ?? 0),
        could_not_say: Number(row.could_not_say_count ?? 0)
      },
      latest_activity_at: row.latest_activity_at ?? null
    };
  }

  async getSpeakingLoopHealthSummary({ weekStart = null } = {}) {
    const start = normalizeWeekStart(weekStart);
    const result = await this.pool.query(
      `SELECT
        COUNT(*) FILTER (WHERE event_type = 'loop_completed')::int AS loop_completion_count,
        COUNT(*) FILTER (WHERE event_type = 'speaking_drill_completed')::int AS drill_session_count
       FROM speaking_events
       WHERE occurred_at >= $1`,
      [start]
    );
    const row = result.rows[0] ?? {};

    const promptResult = await this.pool.query(
      `SELECT updated_at FROM speaking_prompts WHERE status = 'approved' ORDER BY updated_at DESC LIMIT 1`
    );
    const passageResult = await this.pool.query(
      `SELECT created_at FROM memorization_passages WHERE visibility = 'published' AND status = 'published' ORDER BY created_at DESC LIMIT 1`
    );

    return {
      week_start: start.slice(0, 10),
      loop_completion_count: Number(row.loop_completion_count ?? 0),
      drill_session_count: Number(row.drill_session_count ?? 0),
      latest_approved_prompt_at: promptResult.rows[0]?.updated_at ?? null,
      latest_published_passage_at: passageResult.rows[0]?.created_at ?? null,
    };
  }

  async listSpeakingPrompts({ status = null, missingRequired = false, limit = 100 } = {}) {
    const cappedLimit = clampLimit(limit, 200);
    const result = status
      ? await this.pool.query(
          `SELECT * FROM speaking_prompts
          WHERE status = $1
          ORDER BY updated_at DESC
          LIMIT $2`,
          [status, cappedLimit]
        )
      : await this.pool.query(
          `SELECT * FROM speaking_prompts
          ORDER BY updated_at DESC
          LIMIT $1`,
          [cappedLimit]
        );
    let rows = result.rows;
    if (missingRequired) {
      rows = rows.filter(isPromptMissingRequiredFields);
    }
    return rows;
  }

  async createSpeakingPrompt(input) {
    const now = new Date().toISOString();
    const normalized = normalizeSpeakingPromptInput({
      ...input,
      id: input.id ?? createId('speaking_prompt'),
      status: input.status ?? 'pending_review',
      created_at: input.created_at ?? now,
      updated_at: input.updated_at ?? now
    });
    const result = await this.pool.query(
      `INSERT INTO speaking_prompts (
        id, word_sense_id, article_term_id, target_text, vi_hint, target_phrase,
        pronunciation_tip_vi, common_mistake_vi, difficulty, topic, status,
        reviewer_user_id, reviewed_at, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
      RETURNING *`,
      [
        normalized.id,
        normalized.word_sense_id,
        normalized.article_term_id,
        normalized.target_text,
        normalized.vi_hint,
        normalized.target_phrase,
        normalized.pronunciation_tip_vi,
        normalized.common_mistake_vi,
        normalized.difficulty,
        normalized.topic,
        normalized.status,
        normalized.reviewer_user_id,
        normalized.reviewed_at,
        normalized.created_at,
        normalized.updated_at
      ]
    );
    return result.rows[0];
  }

  async updateSpeakingPrompt({ promptId, patch, reviewerUserId = null }) {
    const existing = await this.pool.query(`SELECT * FROM speaking_prompts WHERE id = $1 LIMIT 1`, [promptId]);
    if (!existing.rows[0]) {
      return null;
    }
    const updated = applySpeakingPromptPatch(existing.rows[0], patch, { reviewerUserId, now: new Date().toISOString() });
    const result = await this.pool.query(
      `UPDATE speaking_prompts
      SET
        target_text = $2,
        vi_hint = $3,
        target_phrase = $4,
        pronunciation_tip_vi = $5,
        common_mistake_vi = $6,
        difficulty = $7,
        topic = $8,
        status = $9,
        reviewer_user_id = $10,
        reviewed_at = $11,
        updated_at = $12
      WHERE id = $1
      RETURNING *`,
      [
        promptId,
        updated.target_text,
        updated.vi_hint,
        updated.target_phrase,
        updated.pronunciation_tip_vi,
        updated.common_mistake_vi,
        updated.difficulty,
        updated.topic,
        updated.status,
        updated.reviewer_user_id,
        updated.reviewed_at,
        updated.updated_at
      ]
    );
    return result.rows[0] ?? null;
  }
}
