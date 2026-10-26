// PostgreSQL memorization passages, segments and per-learner segment progress.

import { createId } from '../../ids.js';
import { countWords, mergeSegmentText, splitSegmentText, summarizePassageProgress } from '../../domain/memorization.js';
import { withOptionalTransaction } from './transaction.js';

export class PostgresMemorizationMethods {
  async createPassage({ title, language, rawText, ownerType = 'user', ownerUserId = null, visibility = 'private' }) {
    const now = new Date().toISOString();
    const id = createId('passage');
    const result = await this.pool.query(
      `INSERT INTO memorization_passages (id, title, language, raw_text, owner_type, owner_user_id, visibility, status, enrichment_status, segment_count, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending_segmentation', 'none', 0, $8, $8)
       RETURNING *`,
      [id, title, language, rawText, ownerType, ownerUserId, visibility, now]
    );
    return result.rows[0];
  }

  async getPassage({ passageId }) {
    const result = await this.pool.query(
      `SELECT * FROM memorization_passages WHERE id = $1`,
      [passageId]
    );
    return result.rows[0] ?? null;
  }

  async listPassages({ userId = null, status = null, ownerType = null } = {}) {
    let sql = `SELECT * FROM memorization_passages WHERE 1=1`;
    const params = [];
    let idx = 1;
    if (status) {
      sql += ` AND status = $${idx++}`;
      params.push(status);
    }
    if (ownerType) {
      sql += ` AND owner_type = $${idx++}`;
      params.push(ownerType);
    }
    if (userId) {
      sql += ` AND (owner_user_id = $${idx} OR visibility = 'published')`;
      params.push(userId);
    }
    sql += ` ORDER BY created_at DESC`;
    const result = await this.pool.query(sql, params);
    return result.rows;
  }

  async listPublishedPassages() {
    const result = await this.pool.query(
      `SELECT * FROM memorization_passages WHERE visibility = 'published' AND status = 'published' ORDER BY created_at DESC`
    );
    return result.rows;
  }

  async listAdminPassages({ status = null } = {}) {
    let sql = `SELECT * FROM memorization_passages`;
    const params = [];
    if (status) {
      sql += ` WHERE status = $1`;
      params.push(status);
    }
    sql += ` ORDER BY created_at DESC`;
    const result = await this.pool.query(sql, params);
    return result.rows;
  }

  async updatePassage({ passageId, ...updates }) {
    const allowed = ['title', 'language', 'visibility', 'status', 'enrichment_status', 'processing_error', 'segment_count'];
    const setClauses = [];
    const params = [];
    let idx = 1;
    for (const key of allowed) {
      if (updates[key] !== undefined) {
        setClauses.push(`${key} = $${idx++}`);
        params.push(updates[key]);
      }
    }
    if (setClauses.length === 0) return this.getPassage({ passageId });
    setClauses.push(`updated_at = $${idx++}`);
    params.push(new Date().toISOString());
    params.push(passageId);
    const result = await this.pool.query(
      `UPDATE memorization_passages SET ${setClauses.join(', ')} WHERE id = $${idx} RETURNING *`,
      params
    );
    return result.rows[0] ?? null;
  }

  async deletePassage({ passageId }) {
    const result = await this.pool.query(
      `DELETE FROM memorization_passages WHERE id = $1 RETURNING id`,
      [passageId]
    );
    return result.rows.length > 0;
  }

  // ─── Memorization Segments ──────────────────────────────────────────

  async createSegments({ passageId, segments }) {
    const now = new Date().toISOString();
    const created = [];
    for (const seg of segments) {
      const id = createId('segment');
      const wordCount = seg.text.split(/\s+/).length;
      const result = await this.pool.query(
        `INSERT INTO memorization_segments (id, passage_id, position, text, word_count, created_at)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
        [id, passageId, seg.position, seg.text, wordCount, now]
      );
      created.push(result.rows[0]);
    }
    // Update passage segment_count
    await this.pool.query(
      `UPDATE memorization_passages SET segment_count = $1, updated_at = $2 WHERE id = $3`,
      [created.length, now, passageId]
    );
    return created;
  }

  async getSegmentsByPassage({ passageId }) {
    const result = await this.pool.query(
      `SELECT * FROM memorization_segments WHERE passage_id = $1 ORDER BY position ASC`,
      [passageId]
    );
    return result.rows;
  }

  async updateSegment({ segmentId, text, position }) {
    const setClauses = [];
    const params = [];
    let idx = 1;
    if (text !== undefined) {
      setClauses.push(`text = $${idx++}`);
      params.push(text);
      setClauses.push(`word_count = $${idx++}`);
      params.push(text.split(/\s+/).length);
    }
    if (position !== undefined) {
      setClauses.push(`position = $${idx++}`);
      params.push(position);
    }
    if (setClauses.length === 0) return null;
    params.push(segmentId);
    const result = await this.pool.query(
      `UPDATE memorization_segments SET ${setClauses.join(', ')} WHERE id = $${idx} RETURNING *`,
      params
    );
    return result.rows[0] ?? null;
  }

  async splitSegment({ segmentId, splitAt }) {
    return withOptionalTransaction(this, async (client) => {
      const segmentResult = await client.query(
        `SELECT * FROM memorization_segments WHERE id = $1 LIMIT 1 FOR UPDATE`,
        [segmentId]
      );
      const segment = segmentResult.rows[0];
      if (!segment) return null;

      const split = splitSegmentText(segment.text, splitAt);
      if (!split) {
        return null;
      }
      const { leftText, rightText } = split;

      await client.query(
        `UPDATE memorization_segments
         SET position = position + 1
         WHERE passage_id = $1 AND position > $2`,
        [segment.passage_id, segment.position]
      );
      const leftResult = await client.query(
        `UPDATE memorization_segments
         SET text = $2, word_count = $3
         WHERE id = $1
         RETURNING *`,
        [segmentId, leftText, countWords(leftText)]
      );
      await client.query(
        `INSERT INTO memorization_segments (id, passage_id, position, text, word_count, created_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [createId('segment'), segment.passage_id, segment.position + 1, rightText, countWords(rightText), new Date().toISOString()]
      );
      await client.query(
        `UPDATE memorization_passages
         SET segment_count = (SELECT COUNT(*) FROM memorization_segments WHERE passage_id = $1), updated_at = $2
         WHERE id = $1`,
        [segment.passage_id, new Date().toISOString()]
      );
      const allSegments = await client.query(
        `SELECT * FROM memorization_segments WHERE passage_id = $1 ORDER BY position ASC`,
        [segment.passage_id]
      );
      return allSegments.rows.length > 0 ? allSegments.rows : [leftResult.rows[0]];
    });
  }

  async mergeSegments({ segmentId, nextSegmentId }) {
    return withOptionalTransaction(this, async (client) => {
      const result = await client.query(
        `SELECT * FROM memorization_segments WHERE id = ANY($1) FOR UPDATE`,
        [[segmentId, nextSegmentId]]
      );
      const segment = result.rows.find((row) => row.id === segmentId);
      const next = result.rows.find((row) => row.id === nextSegmentId);
      if (!segment || !next || segment.passage_id !== next.passage_id || next.position !== segment.position + 1) {
        return null;
      }

      const mergedText = mergeSegmentText(segment.text, next.text);
      await client.query(
        `UPDATE memorization_segments SET text = $2, word_count = $3 WHERE id = $1`,
        [segmentId, mergedText, countWords(mergedText)]
      );
      await client.query(
        `UPDATE memorization_segment_progress SET segment_id = $1 WHERE segment_id = $2`,
        [segmentId, nextSegmentId]
      );
      await client.query(
        `UPDATE memorization_segment_terms SET segment_id = $1 WHERE segment_id = $2`,
        [segmentId, nextSegmentId]
      );
      await client.query(`DELETE FROM memorization_segments WHERE id = $1`, [nextSegmentId]);
      await client.query(
        `UPDATE memorization_segments
         SET position = position - 1
         WHERE passage_id = $1 AND position > $2`,
        [segment.passage_id, next.position]
      );
      await client.query(
        `UPDATE memorization_passages
         SET segment_count = (SELECT COUNT(*) FROM memorization_segments WHERE passage_id = $1), updated_at = $2
         WHERE id = $1`,
        [segment.passage_id, new Date().toISOString()]
      );
      const allSegments = await client.query(
        `SELECT * FROM memorization_segments WHERE passage_id = $1 ORDER BY position ASC`,
        [segment.passage_id]
      );
      return allSegments.rows;
    });
  }

  async deleteSegmentsByPassage({ passageId }) {
    await this.pool.query(
      `DELETE FROM memorization_segments WHERE passage_id = $1`,
      [passageId]
    );
    await this.pool.query(
      `UPDATE memorization_passages SET segment_count = 0, updated_at = $1 WHERE id = $2`,
      [new Date().toISOString(), passageId]
    );
  }

  // ─── Memorization Segment Progress ──────────────────────────────────

  async upsertSegmentProgress({ userId, segmentId, status, reviewCount, easeFactor, lastReviewedAt, nextReviewAt }) {
    const now = new Date().toISOString();
    const id = createId('segprog');
    const result = await this.pool.query(
      `INSERT INTO memorization_segment_progress (id, user_id, segment_id, status, review_count, ease_factor, last_reviewed_at, next_review_at, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)
       ON CONFLICT (user_id, segment_id) DO UPDATE SET
         status = COALESCE($4, memorization_segment_progress.status),
         review_count = COALESCE($5, memorization_segment_progress.review_count),
         ease_factor = COALESCE($6, memorization_segment_progress.ease_factor),
         last_reviewed_at = COALESCE($7, memorization_segment_progress.last_reviewed_at),
         next_review_at = COALESCE($8, memorization_segment_progress.next_review_at),
         updated_at = $9
       RETURNING *`,
      [id, userId, segmentId, status ?? 'new', reviewCount ?? 0, easeFactor ?? 2.5, lastReviewedAt ?? null, nextReviewAt ?? null, now]
    );
    return result.rows[0];
  }

  async getSegmentProgress({ userId, passageId }) {
    const result = await this.pool.query(
      `SELECT msp.* FROM memorization_segment_progress msp
       JOIN memorization_segments ms ON ms.id = msp.segment_id
       WHERE msp.user_id = $1 AND ms.passage_id = $2`,
      [userId, passageId]
    );
    return result.rows;
  }

  async getPassageProgress({ userId, passageId }) {
    const [segments, progress] = await Promise.all([
      this.getSegmentsByPassage({ passageId }),
      this.getSegmentProgress({ userId, passageId })
    ]);
    return summarizePassageProgress(segments, progress);
  }

  async claimNextPendingPassage() {
    const result = await this.pool.query(
      `UPDATE memorization_passages
       SET status = 'segmenting', updated_at = $1
       WHERE id = (
         SELECT id FROM memorization_passages
         WHERE status = 'pending_segmentation'
         ORDER BY created_at ASC
         LIMIT 1
         FOR UPDATE SKIP LOCKED
       )
       RETURNING *`,
      [new Date().toISOString()]
    );
    return result.rows[0] ?? null;
  }

  async updateSegmentEnrichment({ segmentId, ipa_text, translation_text, translation_language, viet_reading_text }) {
    const result = await this.pool.query(
      `UPDATE memorization_segments
       SET ipa_text = $2, translation_text = $3, translation_language = $4, viet_reading_text = $5
       WHERE id = $1
       RETURNING *`,
      [segmentId, ipa_text ?? null, translation_text ?? null, translation_language ?? null, viet_reading_text ?? null]
    );
    return result.rows[0] ?? null;
  }

  async updatePassageEnrichmentStatus({ passageId, enrichmentStatus, enrichment_attempt_count }) {
    const now = new Date().toISOString();
    let result;
    if (enrichment_attempt_count !== undefined) {
      result = await this.pool.query(
        `UPDATE memorization_passages
         SET enrichment_status = $2, enrichment_attempt_count = $3, updated_at = $4
         WHERE id = $1
         RETURNING *`,
        [passageId, enrichmentStatus, enrichment_attempt_count, now]
      );
    } else {
      result = await this.pool.query(
        `UPDATE memorization_passages
         SET enrichment_status = $2, updated_at = $3
         WHERE id = $1
         RETURNING *`,
        [passageId, enrichmentStatus, now]
      );
    }
    return result.rows[0] ?? null;
  }

  async retryPassage({ passageId }) {
    const result = await this.pool.query(
      `UPDATE memorization_passages
       SET status = 'pending_segmentation', processing_error = NULL, attempt_count = 0, updated_at = $2
       WHERE id = $1 AND status = 'failed'
       RETURNING *`,
      [passageId, new Date().toISOString()]
    );
    if (result.rows.length === 0) {
      // Check whether it exists at all to distinguish 404 vs wrong status
      const check = await this.pool.query(
        'SELECT id, status FROM memorization_passages WHERE id = $1',
        [passageId]
      );
      if (check.rows.length === 0) return { error: 'not_found' };
      return { error: 'passage_not_failed' };
    }
    return { passage: result.rows[0] };
  }

  async retryPassageEnrichment({ passageId }) {
    // Validate passage exists and enrichment_status is 'failed'
    const check = await this.pool.query(
      `SELECT p.id, p.enrichment_status,
              (SELECT COUNT(*) FROM memorization_segments WHERE passage_id = p.id)::int AS segment_count
       FROM memorization_passages p WHERE p.id = $1`,
      [passageId]
    );
    if (check.rows.length === 0) return { error: 'not_found' };
    const row = check.rows[0];
    if (row.enrichment_status !== 'failed') return { error: 'enrichment_not_failed' };
    if (row.segment_count === 0) return { error: 'passage_has_no_segments' };

    const result = await this.pool.query(
      `UPDATE memorization_passages
       SET enrichment_status = 'pending', enrichment_attempt_count = 0, updated_at = $2
       WHERE id = $1
       RETURNING *`,
      [passageId, new Date().toISOString()]
    );
    return { passage: result.rows[0] };
  }

  async claimNextPendingEnrichment() {
    const result = await this.pool.query(
      `UPDATE memorization_passages
       SET enrichment_status = 'enriching', updated_at = $1
       WHERE id = (
         SELECT id FROM memorization_passages
         WHERE enrichment_status = 'pending'
         ORDER BY created_at ASC
         LIMIT 1
         FOR UPDATE SKIP LOCKED
       )
       RETURNING *`,
      [new Date().toISOString()]
    );
    return result.rows[0] ?? null;
  }
}
