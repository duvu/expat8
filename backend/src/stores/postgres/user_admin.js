// PostgreSQL account administration: password reset and full account deletion.
// The set of tables touched here is mirrored by USER_REFERENCES in
// domain/user_admin.js, which the integration test checks against the schema.

import { emptyDeletionSummary } from '../../domain/user_admin.js';
import { createPasswordHash } from '../../user_identity.js';
import { withOptionalTransaction } from './transaction.js';

export class PostgresUserAdminMethods {
  async findUserById({ userId }) {
    const result = await this.pool.query(
      'SELECT id, identifier, display_name FROM users WHERE id = $1 LIMIT 1',
      [userId]
    );
    return result.rows[0] ?? null;
  }

  /** Sets a new password and revokes every session of the user. Returns null for an unknown user. */
  async resetUserPassword({ userId, password }) {
    const passwordHash = await createPasswordHash(password);
    return withOptionalTransaction(this, async (client) => {
      const now = new Date().toISOString();
      const updated = await client.query(
        'UPDATE users SET password_hash = $2, updated_at = $3 WHERE id = $1 RETURNING id, identifier',
        [userId, passwordHash, now]
      );
      if (!updated.rows[0]) {
        return null;
      }
      const revoked = await client.query(
        'UPDATE user_sessions SET revoked_at = $2 WHERE user_id = $1 AND revoked_at IS NULL',
        [userId, now]
      );
      return { user: updated.rows[0], revokedSessions: revoked.rowCount };
    });
  }

  /**
   * Permanently deletes the account and everything tied to it in one
   * transaction (same scope as db/ops/delete_user.sql). Anonymous data on the
   * user's devices goes too; rows another account owns on a shared device stay.
   * Returns the deleted row counts, or null for an unknown user.
   */
  async deleteUser({ userId }) {
    return withOptionalTransaction(this, async (client) => {
      const run = async (sql, params = [userId]) => (await client.query(sql, params)).rowCount;
      const column = async (sql, params = [userId]) => (await client.query(sql, params)).rows.map((row) => row.id);

      if (!(await client.query('SELECT 1 FROM users WHERE id = $1 FOR UPDATE', [userId])).rows[0]) {
        return null;
      }
      const summary = emptyDeletionSummary();
      const devices = await column(
        'SELECT DISTINCT device_id AS id FROM user_sessions WHERE user_id = $1 AND device_id IS NOT NULL'
      );
      const articleIds = await column('SELECT id FROM articles WHERE owner_user_id = $1');
      const termIds = await column('SELECT id FROM article_terms WHERE article_id = ANY($1)', [articleIds]);
      const senseIds = await column(
        `SELECT word_sense_id AS id FROM article_terms WHERE article_id = ANY($1) AND word_sense_id IS NOT NULL
         UNION
         SELECT t.word_sense_id FROM memorization_segment_terms t
         JOIN memorization_passages p ON p.id = t.passage_id
         WHERE p.owner_user_id = $2 AND t.word_sense_id IS NOT NULL`,
        [articleIds, userId]
      );
      const sentenceIds = await column(
        'SELECT workplace_sentence_id AS id FROM article_workplace_sentences WHERE article_id = ANY($1)',
        [articleIds]
      );
      const examSessionIds = await column('SELECT id FROM exam_sessions WHERE user_id = $1');

      // Content the learner owns.
      await run('UPDATE speaking_prompts SET article_term_id = NULL WHERE article_term_id = ANY($1)', [termIds]);
      await run('DELETE FROM vocabulary_review_items WHERE article_id = ANY($1)', [articleIds]);
      await run('DELETE FROM article_terms WHERE article_id = ANY($1)', [articleIds]);
      await run('DELETE FROM article_workplace_sentences WHERE article_id = ANY($1)', [articleIds]);
      await run(
        `DELETE FROM workplace_sentences ws WHERE ws.id = ANY($1)
         AND NOT EXISTS (SELECT 1 FROM article_workplace_sentences a WHERE a.workplace_sentence_id = ws.id)`,
        [sentenceIds]
      );
      await run('DELETE FROM article_processing_jobs WHERE article_id = ANY($1)', [articleIds]);
      summary.articles = await run('DELETE FROM articles WHERE id = ANY($1)', [articleIds]);

      // Segments, segment terms and every learner's progress cascade from the passage.
      summary.memorization_progress = await run('DELETE FROM memorization_segment_progress WHERE user_id = $1');
      summary.memorization_content = await run('DELETE FROM memorization_passages WHERE owner_user_id = $1');

      // Word senses that only existed for the deleted content.
      await run('DELETE FROM vocabulary_review_items WHERE word_sense_id = ANY($1)', [senseIds]);
      await run(
        `DELETE FROM word_senses s
         WHERE s.id = ANY($1)
           AND NOT EXISTS (SELECT 1 FROM article_terms x WHERE x.word_sense_id = s.id)
           AND NOT EXISTS (SELECT 1 FROM memorization_segment_terms x WHERE x.word_sense_id = s.id)
           AND NOT EXISTS (SELECT 1 FROM content_pack_items x WHERE x.word_sense_id = s.id)
           AND NOT EXISTS (SELECT 1 FROM speaking_prompts x WHERE x.word_sense_id = s.id)
           AND NOT EXISTS (SELECT 1 FROM speaking_events x WHERE x.word_sense_id = s.id)`,
        [senseIds]
      );

      summary.shadowing_entries = await run(
        `DELETE FROM shadowing_video_entries
         WHERE owner_user_id = $1 OR (owner_user_id IS NULL AND owner_device_id = ANY($2))`,
        [userId, devices]
      );

      // Exam history.
      summary.exam_rows += await run(
        `DELETE FROM exam_certificates WHERE user_id = $1
         OR attempt_id IN (SELECT id FROM exam_attempts WHERE session_id = ANY($2))`,
        [userId, examSessionIds]
      );
      summary.exam_rows += await run(
        'DELETE FROM exam_attempts WHERE user_id = $1 OR session_id = ANY($2)',
        [userId, examSessionIds]
      );
      summary.exam_rows += await run('DELETE FROM exam_questions WHERE session_id = ANY($1)', [examSessionIds]);
      summary.exam_rows += await run('DELETE FROM exam_sessions WHERE id = ANY($1)', [examSessionIds]);

      // Submitted words and learning history of the account and of anonymous use on its devices.
      await run(
        `DELETE FROM user_submitted_word_jobs WHERE submission_id IN
         (SELECT id FROM user_submitted_words WHERE user_id = $1 OR (user_id IS NULL AND device_id = ANY($2)))`,
        [userId, devices]
      );
      summary.submitted_words = await run(
        'DELETE FROM user_submitted_words WHERE user_id = $1 OR (user_id IS NULL AND device_id = ANY($2))',
        [userId, devices]
      );
      const ownedOrAnonymous = 'user_id = $1 OR (user_id IS NULL AND device_id = ANY($2))';
      const owned = [userId, devices];
      summary.speaking_events = await run(`DELETE FROM speaking_events WHERE ${ownedOrAnonymous}`, owned);
      summary.study_events = await run(`DELETE FROM study_events WHERE ${ownedOrAnonymous}`, owned);
      summary.game_rounds = await run(`DELETE FROM game_rounds WHERE ${ownedOrAnonymous}`, owned);
      summary.word_states = await run(`DELETE FROM user_word_states WHERE ${ownedOrAnonymous}`, owned);
      summary.cached_words = await run(`DELETE FROM user_cached_words WHERE ${ownedOrAnonymous}`, owned);
      summary.proficiency = await run(`DELETE FROM user_proficiency WHERE ${ownedOrAnonymous}`, owned);

      // Keep shared admin content; only drop the reference to this reviewer.
      summary.cleared_reviewer_refs =
        (await run('UPDATE vocabulary_review_items SET reviewer_user_id = NULL WHERE reviewer_user_id = $1')) +
        (await run('UPDATE speaking_prompts SET reviewer_user_id = NULL WHERE reviewer_user_id = $1'));

      summary.sessions = await run('DELETE FROM user_sessions WHERE user_id = $1');
      summary.user = await run('DELETE FROM users WHERE id = $1');
      return summary;
    });
  }
}
