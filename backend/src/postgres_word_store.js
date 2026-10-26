import crypto from 'node:crypto';

import { isGameSource, normalizeEventSource } from './game_rounds.js';
import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
import { normalizeSuggestionType } from './vocabulary_validator.js';
import { normalizeSentenceText } from './workplace_sentence_validator.js';
import { getDefaultProficiencyLevel, requireStudyRating } from './proficiency.js';
import {
  DuplicateUserError,
  InvalidCredentialsError,
  createPasswordHash,
  createSessionToken,
  hashSessionToken,
  normalizeUserIdentifier,
  requireRegistrationInput,
  verifyPassword
} from './user_identity.js';
import { ADMIN_ARTICLE_PATCH_FIELDS, buildArticle, staleArticleJobCutoff } from './domain/articles.js';
import { composeLearningCards, newCardWordIds } from './domain/learning_cards.js';
import { replaySrsState } from './domain/srs.js';
import { clampLimit } from './domain/pagination.js';
import { planLevelChange, toProficiencyResponse } from './domain/proficiency_progress.js';
import { toApiSpeakingPrompt } from './domain/speaking.js';
import { resolveEventKey, routeStudyEvents, toSyncResponse } from './domain/study_events.js';
import { buildSubmittedWord, normalizeSubmittedTerm, submittedWordFailureReason } from './domain/submitted_words.js';
import {
  articleItemRequiresReview,
  bridgedWordInput,
  buildWordRecord,
  passageRequiresReview,
  pickTermSample,
  reviewStatuses,
  senseFieldsFromItem,
  tallyWordLevels,
  toApiWord
} from './domain/vocabulary.js';
import { MAX_CACHED_WORD_IDS, distinctWordIds } from './domain/word_cache.js';
import { mixinMethods } from './stores/mixin.js';
import { PostgresExamMethods } from './stores/postgres/exam.js';
import { PostgresGameMethods } from './stores/postgres/games.js';
import { PostgresMemorizationMethods } from './stores/postgres/memorization.js';
import { PostgresShadowingMethods } from './stores/postgres/shadowing.js';
import { PostgresSpeakingMethods } from './stores/postgres/speaking.js';
import { withOptionalTransaction } from './stores/postgres/transaction.js';

/** Production store backed by PostgreSQL; shared business rules live in `domain/`. */
export class PostgresWordStore {
  constructor({ pool, logger = console, strictAttemptId = false }) {
    this.pool = pool;
    this.logger = logger;
    this.strictAttemptId = strictAttemptId;
  }

  async insertWord(input, { client = this.pool } = {}) {
    const startedAt = Date.now();
    const { topics, ...word } = buildWordRecord(input);
    const row = { ...word, topics_json: JSON.stringify(topics) };

    const inserted = await client.query(
      `INSERT INTO words (
        id,
        term,
        normalized_term,
        language,
        meaning_vi,
        part_of_speech,
        ipa,
        vietnamese_pronunciation,
        example,
        example_vi,
        difficulty,
        topics_json,
        entry_type,
        blank_word,
        explanation,
        generation_source,
        created_at,
        updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
      ON CONFLICT (language, normalized_term) DO NOTHING
      RETURNING *`,
      [
        row.id,
        row.term,
        row.normalized_term,
        row.language,
        row.meaning_vi,
        row.part_of_speech,
        row.ipa,
        row.vietnamese_pronunciation,
        row.example,
        row.example_vi,
        row.difficulty,
        row.topics_json,
        row.entry_type,
        row.blank_word,
        row.explanation,
        row.generation_source,
        row.created_at,
        row.updated_at
      ]
    );

    if (inserted.rows[0]) {
      this.logger.debug?.('db_insert_word_completed', {
        language: row.language,
        inserted: true,
        elapsed_ms: Date.now() - startedAt
      });
      return { word: rowToWord(inserted.rows[0]), inserted: true };
    }

    const existing = await client.query(
      `SELECT * FROM words
      WHERE language = $1 AND normalized_term = $2
      LIMIT 1`,
      [row.language, row.normalized_term]
    );
    this.logger.debug?.('db_insert_word_completed', {
      language: row.language,
      inserted: false,
      elapsed_ms: Date.now() - startedAt
    });
    return { word: rowToWord(existing.rows[0]), inserted: false };
  }

  async recentWords({ targetLanguage = 'en', limit = 1000 }) {
    const result = await this.pool.query(
      `SELECT * FROM words
      WHERE language = $1
      ORDER BY updated_at DESC
      LIMIT $2`,
      [targetLanguage, Math.min(limit, 1000)]
    );
    return result.rows.map(rowToWord);
  }

  async recentWorkplaceSentences({ targetLanguage = 'en', limit = 1000 }) {
    const result = await this.pool.query(
      `SELECT * FROM (
        SELECT DISTINCT ON (ws.id)
          ws.*, a.id AS source_article_id, a.title AS source_title
        FROM workplace_sentences ws
        JOIN article_workplace_sentences aws ON aws.workplace_sentence_id = ws.id
        JOIN articles a ON a.id = aws.article_id
        WHERE ws.language = $1
          AND a.status = 'published'
          AND a.visibility = 'published'
        ORDER BY ws.id, a.updated_at DESC, aws.created_at DESC
      ) visible_sentences
      ORDER BY updated_at DESC
      LIMIT $2`,
      [targetLanguage, Math.min(limit, 1000)]
    );
    return result.rows.map(rowToWorkplaceSentence);
  }

  async countUsableWords({ targetLanguage = 'en' } = {}) {
    const result = await this.pool.query(`SELECT COUNT(*)::int AS count FROM words WHERE language = $1`, [
      targetLanguage
    ]);
    return Number(result.rows[0]?.count ?? 0);
  }

  async hasCrawledUrl({ url }) {
    const result = await this.pool.query(`SELECT 1 FROM crawled_urls WHERE url_hash = $1 LIMIT 1`, [hashUrl(url)]);
    return result.rowCount > 0;
  }

  async recordCrawledUrl({
    url,
    feedUrl = null,
    status,
    reason = null,
    level = null,
    quality = null,
    articleId = null
  }) {
    await this.pool.query(
      `INSERT INTO crawled_urls (url_hash, url, feed_url, status, reason, cefr_level, quality, article_id, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      ON CONFLICT (url_hash) DO NOTHING`,
      [hashUrl(url), url, feedUrl, status, reason, level, quality, articleId, new Date().toISOString()]
    );
  }

  async curatedStats() {
    const result = await this.pool.query(
      `SELECT COUNT(*)::int AS queued, MAX(created_at) AS last_queued_at
      FROM crawled_urls
      WHERE status = 'queued' AND feed_url LIKE 'curated:%'`
    );
    return { queued: Number(result.rows[0].queued), lastQueuedAt: result.rows[0].last_queued_at ?? null };
  }

  async countWordsByLevel({ targetLanguage = 'en' } = {}) {
    const result = await this.pool.query(
      `SELECT difficulty, COUNT(*)::int AS count FROM words WHERE language = $1 GROUP BY difficulty`,
      [targetLanguage]
    );
    return tallyWordLevels(result.rows, targetLanguage);
  }

  async sampleWordTerms({ targetLanguage = 'en', level = null, limit = 150 } = {}) {
    const result = await this.pool.query(
      `SELECT term, difficulty, created_at FROM words WHERE language = $1 ORDER BY created_at DESC LIMIT 3000`,
      [targetLanguage]
    );
    return pickTermSample(result.rows, { targetLanguage, level, limit });
  }

  async recordGenerationRun(input) {
    const now = new Date().toISOString();
    const row = {
      id: input.id ?? createId('generation_run'),
      target_language: input.targetLanguage,
      mode: input.mode,
      status: input.status,
      requested_count: input.requestedCount ?? 0,
      inserted_count: input.insertedCount ?? 0,
      error_message: input.errorMessage ?? null,
      run_date: input.runDate ?? now.slice(0, 10),
      started_at: input.startedAt ?? now,
      finished_at: input.finishedAt ?? now
    };
    await this.pool.query(
      `INSERT INTO generation_runs (
        id,
        target_language,
        mode,
        status,
        requested_count,
        inserted_count,
        error_message,
        run_date,
        started_at,
        finished_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        row.id,
        row.target_language,
        row.mode,
        row.status,
        row.requested_count,
        row.inserted_count,
        row.error_message,
        row.run_date,
        row.started_at,
        row.finished_at
      ]
    );
    return row;
  }

  async hasGenerationRun({ targetLanguage = 'en', mode, runDate }) {
    const result = await this.pool.query(
      `SELECT id FROM generation_runs
      WHERE target_language = $1 AND mode = $2 AND run_date = $3 AND status = 'success'
      LIMIT 1`,
      [targetLanguage, mode, runDate]
    );
    return result.rows.length > 0;
  }

  async acquireGenerationLock({ targetLanguage = 'en', ownerId, now = new Date(), ttlSeconds = 120 } = {}) {
    const nowIso = now.toISOString();
    const expiresAt = new Date(now.getTime() + ttlSeconds * 1000).toISOString();
    const result = await this.pool.query(
      `INSERT INTO scheduler_locks (target_language, owner_id, expires_at, updated_at)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (target_language) DO UPDATE
      SET owner_id = EXCLUDED.owner_id,
          expires_at = EXCLUDED.expires_at,
          updated_at = EXCLUDED.updated_at
      WHERE scheduler_locks.expires_at <= $4 OR scheduler_locks.owner_id = $2
      RETURNING *`,
      [targetLanguage, ownerId, expiresAt, nowIso]
    );
    return result.rows.length > 0;
  }

  async releaseGenerationLock({ targetLanguage = 'en', ownerId } = {}) {
    await this.pool.query(
      `DELETE FROM scheduler_locks
      WHERE target_language = $1 AND owner_id = $2`,
      [targetLanguage, ownerId]
    );
  }

  async replaceCachedWordIds({ deviceId, userId = null, wordIds = [], observedAt = new Date().toISOString() }) {
    return this.#withOptionalTransaction(async (client) => {
      const { stored, unknown } = await this.#partitionKnownWordIds(client, wordIds);
      const ownerWhere = userId ? 'user_id = $1' : 'device_id = $1 AND user_id IS NULL';
      await client.query(`DELETE FROM user_cached_words WHERE ${ownerWhere}`, [userId ?? deviceId]);
      const now = new Date().toISOString();
      for (const wordId of stored) {
        await client.query(
          `INSERT INTO user_cached_words (
            device_id,
            user_id,
            word_id,
            observed_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT DO NOTHING`,
          [deviceId, userId, wordId, observedAt, now]
        );
      }
      return {
        stored_count: stored.length,
        unknown_server_word_ids: unknown
      };
    });
  }

  async addCachedWordIds({ deviceId, userId = null, wordIds = [], observedAt = new Date().toISOString() }) {
    return this.#withOptionalTransaction(async (client) => {
      const { stored, unknown } = await this.#partitionKnownWordIds(client, wordIds);
      const now = new Date().toISOString();
      for (const wordId of stored) {
        const params = [deviceId, userId, wordId, observedAt, now];
        const updateResult = userId
          ? await client.query(
              `UPDATE user_cached_words
              SET
                device_id = $1,
                observed_at = $4,
                updated_at = $5
              WHERE user_id = $2 AND word_id = $3`,
              params
            )
          : await client.query(
              `UPDATE user_cached_words
              SET
                observed_at = $3,
                updated_at = $4
              WHERE device_id = $1 AND user_id IS NULL AND word_id = $2`,
              [deviceId, wordId, observedAt, now]
            );
        if (updateResult.rowCount > 0) {
          continue;
        }
        await client.query(
          `INSERT INTO user_cached_words (
            device_id,
            user_id,
            word_id,
            observed_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT DO NOTHING`,
          params
        );
      }
      return {
        stored_count: stored.length,
        unknown_server_word_ids: unknown
      };
    });
  }

  // Splits requested ids into known words (capped) and unknown ids.
  async #partitionKnownWordIds(client, wordIds) {
    const distinctIds = distinctWordIds(wordIds);
    const knownResult =
      distinctIds.length === 0
        ? { rows: [] }
        : await client.query(`SELECT id FROM words WHERE id = ANY($1)`, [distinctIds]);
    const knownIds = new Set(knownResult.rows.map((row) => row.id));
    return {
      stored: distinctIds.filter((wordId) => knownIds.has(wordId)).slice(0, MAX_CACHED_WORD_IDS),
      unknown: distinctIds.filter((wordId) => !knownIds.has(wordId))
    };
  }

  async cachedWordIdsFor({ deviceId, userId = null }) {
    const result = userId
      ? await this.pool.query(`SELECT word_id FROM user_cached_words WHERE user_id = $1`, [userId])
      : await this.pool.query(`SELECT word_id FROM user_cached_words WHERE device_id = $1 AND user_id IS NULL`, [
          deviceId
        ]);
    return new Set(result.rows.map((row) => row.word_id));
  }

  async createUserSubmittedWord({ deviceId, userId = null, term, language, generationService = null }) {
    return this.#withOptionalTransaction(async (client) => {
      const { submittedTerm, normalizedTerm } = normalizeSubmittedTerm(term);
      const now = new Date().toISOString();
      const ownerWhere = userId
        ? 'user_id = $1 AND language = $2 AND normalized_term = $3'
        : 'device_id = $1 AND user_id IS NULL AND language = $2 AND normalized_term = $3';
      const ownerParams = userId ? [userId, language, normalizedTerm] : [deviceId, language, normalizedTerm];
      const respond = async (submission, created) => ({
        submission: await this.#hydrateSubmittedWord(client, submission),
        created
      });
      const save = (fields) =>
        this.#insertSubmittedWord(
          client,
          buildSubmittedWord({ deviceId, userId, submittedTerm, normalizedTerm, language, now, ...fields })
        );

      const activeResult = await client.query(
        `SELECT * FROM user_submitted_words
         WHERE ${ownerWhere} AND status IN ('queued', 'processing')
         ORDER BY created_at DESC
         LIMIT 1`,
        ownerParams
      );
      if (activeResult.rows[0]) {
        return respond(rowToSubmittedWord(activeResult.rows[0]), false);
      }

      const readyResult = await client.query(
        `SELECT * FROM user_submitted_words
         WHERE ${ownerWhere} AND status = 'ready' AND resolved_word_id IS NOT NULL
         ORDER BY created_at DESC
         LIMIT 1`,
        ownerParams
      );
      if (readyResult.rows[0]) {
        return respond(rowToSubmittedWord(readyResult.rows[0]), false);
      }

      const existingWordResult = await client.query(
        `SELECT * FROM words WHERE language = $1 AND normalized_term = $2 LIMIT 1`,
        [language, normalizedTerm]
      );
      if (existingWordResult.rows[0]) {
        const resolvedWordId = existingWordResult.rows[0].id;
        return respond(await save({ status: 'ready', resolutionType: 'existing_word', resolvedWordId }), false);
      }

      if (generationService?.generateSubmittedWord) {
        try {
          const generated = await generationService.generateSubmittedWord({
            targetLanguage: language,
            term: submittedTerm,
            persistWord: (candidate) => this.insertWord(candidate, { client })
          });
          const resolutionType = generated.resolutionType ?? 'generated_word';
          return respond(await save({ status: 'ready', resolutionType, resolvedWordId: generated.word.id }), true);
        } catch (error) {
          return respond(await save({ status: 'failed', failureReason: submittedWordFailureReason(error) }), true);
        }
      }

      const submission = await save({ status: 'queued' });
      await client.query(
        `INSERT INTO user_submitted_word_jobs (
          id,
          submission_id,
          status,
          attempt_count,
          queued_at,
          started_at,
          finished_at,
          error_message,
          created_at,
          updated_at
        )
        VALUES ($1, $2, 'queued', 0, $3, NULL, NULL, NULL, $3, $3)`,
        [createId('submitted_word_job'), submission.id, now]
      );
      return respond(submission, true);
    });
  }

  async #insertSubmittedWord(client, record) {
    const result = await client.query(
      `INSERT INTO user_submitted_words (
        id,
        user_id,
        device_id,
        submitted_term,
        normalized_term,
        language,
        status,
        failure_reason,
        resolution_type,
        resolved_word_id,
        created_at,
        updated_at,
        resolved_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *`,
      [
        record.id,
        record.user_id,
        record.device_id,
        record.submitted_term,
        record.normalized_term,
        record.language,
        record.status,
        record.failure_reason,
        record.resolution_type,
        record.resolved_word_id,
        record.created_at,
        record.updated_at,
        record.resolved_at
      ]
    );
    return rowToSubmittedWord(result.rows[0]);
  }

  async listUserSubmittedWords({ deviceId, userId = null, limit = 50 }) {
    const result = userId
      ? await this.pool.query(
          `SELECT * FROM user_submitted_words
           WHERE user_id = $1
           ORDER BY updated_at DESC
           LIMIT $2`,
          [userId, clampLimit(limit, 100)]
        )
      : await this.pool.query(
          `SELECT * FROM user_submitted_words
           WHERE device_id = $1 AND user_id IS NULL
           ORDER BY updated_at DESC
           LIMIT $2`,
          [deviceId, clampLimit(limit, 100)]
        );
    return this.#hydrateSubmittedWords(this.pool, result.rows.map(rowToSubmittedWord));
  }

  async getUserSubmittedWordById({ submissionId }) {
    const result = await this.pool.query(`SELECT * FROM user_submitted_words WHERE id = $1 LIMIT 1`, [submissionId]);
    if (!result.rows[0]) {
      return null;
    }
    return this.#hydrateSubmittedWord(this.pool, rowToSubmittedWord(result.rows[0]));
  }

  async claimNextSubmittedWordJob() {
    return this.#withOptionalTransaction(async (client) => {
      const now = new Date().toISOString();
      const updated = await client.query(
        `UPDATE user_submitted_word_jobs
         SET status = 'processing',
             attempt_count = attempt_count + 1,
             started_at = $1,
             updated_at = $1
         WHERE id = (
           SELECT id FROM user_submitted_word_jobs
           WHERE status = 'queued'
           ORDER BY queued_at ASC
           LIMIT 1
           FOR UPDATE SKIP LOCKED
         )
         RETURNING *`,
        [now]
      );
      const job = updated.rows[0];
      if (!job) {
        return null;
      }
      await client.query(
        `UPDATE user_submitted_words
         SET status = 'processing',
             failure_reason = NULL,
             updated_at = $2
         WHERE id = $1`,
        [job.submission_id, now]
      );
      return job;
    });
  }

  async completeSubmittedWordJob({ jobId, resolvedWordId, resolutionType = 'generated_word' }) {
    return this.#withOptionalTransaction(async (client) => {
      const now = new Date().toISOString();
      const updated = await client.query(
        `UPDATE user_submitted_word_jobs
         SET status = 'completed',
             error_message = NULL,
             finished_at = $2,
             updated_at = $2
         WHERE id = $1
         RETURNING *`,
        [jobId, now]
      );
      const job = updated.rows[0];
      if (!job) {
        return null;
      }
      const submissionResult = await client.query(
        `UPDATE user_submitted_words
         SET status = 'ready',
             failure_reason = NULL,
             resolution_type = $2,
             resolved_word_id = $3,
             updated_at = $4,
             resolved_at = $4
         WHERE id = $1
         RETURNING *`,
        [job.submission_id, resolutionType, resolvedWordId, now]
      );
      return this.#hydrateSubmittedWord(client, rowToSubmittedWord(submissionResult.rows[0]));
    });
  }

  async retrySubmittedWordJob({ jobId, errorMessage = null }) {
    return this.#withOptionalTransaction(async (client) => {
      const now = new Date().toISOString();
      const updated = await client.query(
        `UPDATE user_submitted_word_jobs
         SET status = 'queued',
             error_message = $2,
             finished_at = NULL,
             updated_at = $3
         WHERE id = $1
         RETURNING *`,
        [jobId, errorMessage, now]
      );
      const job = updated.rows[0];
      if (!job) {
        return null;
      }
      const submissionResult = await client.query(
        `UPDATE user_submitted_words
         SET status = 'queued',
             failure_reason = NULL,
             updated_at = $2
         WHERE id = $1
         RETURNING *`,
        [job.submission_id, now]
      );
      return this.#hydrateSubmittedWord(client, rowToSubmittedWord(submissionResult.rows[0]));
    });
  }

  async failSubmittedWordJob({ jobId, errorMessage }) {
    return this.#withOptionalTransaction(async (client) => {
      const now = new Date().toISOString();
      const updated = await client.query(
        `UPDATE user_submitted_word_jobs
         SET status = 'failed',
             error_message = $2,
             finished_at = $3,
             updated_at = $3
         WHERE id = $1
         RETURNING *`,
        [jobId, errorMessage, now]
      );
      const job = updated.rows[0];
      if (!job) {
        return null;
      }
      const submissionResult = await client.query(
        `UPDATE user_submitted_words
         SET status = 'failed',
             failure_reason = $2,
             updated_at = $3
         WHERE id = $1
         RETURNING *`,
        [job.submission_id, errorMessage, now]
      );
      return this.#hydrateSubmittedWord(client, rowToSubmittedWord(submissionResult.rows[0]));
    });
  }

  /** The owner's states for `language` changed after `cursor`, oldest first, each with its word. */
  async listWordStatesSince({ deviceId, userId = null, language, cursor = null, limit }) {
    const owner = userId ? 'user_id = $1' : 'device_id = $1 AND user_id IS NULL';
    const states = await this.pool.query(
      `SELECT * FROM user_word_states
      WHERE ${owner} AND language = $2 AND (updated_at, id) > ($3, $4)
      ORDER BY updated_at, id
      LIMIT $5`,
      [userId ?? deviceId, language, cursor?.updatedAt ?? '', cursor?.id ?? '', limit]
    );
    const wordIds = states.rows.map((state) => state.word_id);
    const words = wordIds.length
      ? await this.pool.query(`SELECT * FROM words WHERE id = ANY($1)`, [wordIds])
      : { rows: [] };
    const wordById = new Map(words.rows.map((row) => [row.id, rowToWord(row)]));
    return states.rows.map((state) => ({ state, word: wordById.get(state.word_id) ?? null }));
  }

  async wordStateFor({ deviceId, userId = null, wordId }) {
    const result = userId
      ? await this.pool.query(`SELECT * FROM user_word_states WHERE user_id = $1 AND word_id = $2 LIMIT 1`, [
          userId,
          wordId
        ])
      : await this.pool.query(
          `SELECT * FROM user_word_states WHERE device_id = $1 AND user_id IS NULL AND word_id = $2 LIMIT 1`,
          [deviceId, wordId]
        );
    return result.rows[0] ?? null;
  }

  async learningCards({
    deviceId,
    userId = null,
    targetLanguage = 'en',
    limit = 10,
    level: levelOverride = null,
    now = new Date().toISOString()
  }) {
    const [wordsResult, cachedWordIds, stateResult, proficiency] = await Promise.all([
      this.pool.query(`SELECT * FROM words WHERE language = $1`, [targetLanguage]),
      this.#cachedWordIdsForSelection({ deviceId, userId }),
      userId
        ? this.pool.query(
            `SELECT * FROM user_word_states
            WHERE language = $3
            AND (user_id = $1 OR (device_id = $2 AND user_id IS NULL))`,
            [userId, deviceId, targetLanguage]
          )
        : this.pool.query(`SELECT * FROM user_word_states WHERE device_id = $1 AND user_id IS NULL AND language = $2`, [
            deviceId,
            targetLanguage
          ]),
      levelOverride ? null : this.getProficiency({ deviceId, userId, language: targetLanguage })
    ]);
    const words = wordsResult.rows.map(rowToWord);
    const batch = composeLearningCards({
      wordById: new Map(words.map((word) => [word.id, word])),
      candidateWords: words,
      states: stateResult.rows,
      cachedWordIds,
      level: levelOverride ?? proficiency.level,
      language: targetLanguage,
      limit,
      now
    });
    await this.addCachedWordIds({ deviceId, userId, wordIds: newCardWordIds(batch), observedAt: now });
    return batch;
  }

  async syncStudyEvents({ deviceId, events, language = 'en', userId = null }) {
    const startedAt = Date.now();
    const outcome = await routeStudyEvents({
      events,
      initialProficiency: await this.getProficiency({ deviceId, userId, language }),
      recordSpeakingEvent: (event) => this.recordSpeakingEvent({ deviceId, userId, event, language }),
      recordStudyEvent: (event) => this.recordStudyEvent({ deviceId, userId, event, language })
    });

    this.logger.info?.('db_sync_study_events_completed', {
      device_id: deviceId,
      accepted_count: outcome.accepted.length,
      duplicate_count: outcome.duplicates.length,
      rejected_count: outcome.rejected.length,
      elapsed_ms: Date.now() - startedAt
    });
    return toSyncResponse(outcome);
  }

  async recordStudyEvent({ deviceId, event, language = 'en', userId = null }) {
    requireStudyRating(event.rating);
    const eventKey = resolveEventKey(event);
    if (!eventKey) {
      throw new Error('missing_event_id');
    }

    return this.#withOptionalTransaction(async (client) => {
      const startedAt = Date.now();
      const receivedAt = new Date().toISOString();
      const inserted = await client.query(
        `INSERT INTO study_events (
          id,
          event_id,
          client_event_id,
          device_id,
          user_id,
          word_id,
          local_word_id,
          rating,
          occurred_at,
          received_at,
          source
        )
        SELECT $1, $2, $3, $4, $5,
          (SELECT id FROM words WHERE id = $6 LIMIT 1),
          $7, $8, $9, $10, $11
        ON CONFLICT (client_event_id) DO NOTHING
        RETURNING *`,
        [
          createId('study_event'),
          event.event_id ?? eventKey,
          event.client_event_id ?? eventKey,
          deviceId,
          userId ?? event.user_id ?? null,
          event.server_word_id ?? null,
          event.local_word_id ?? null,
          event.rating,
          event.occurred_at,
          receivedAt,
          normalizeEventSource(event.source)
        ]
      );

      const eventUserId = userId ?? event.user_id ?? null;
      const proficiency = await this.getOrInitializeProficiency({
        client,
        deviceId,
        userId: eventUserId,
        language
      });

      if (!inserted.rows[0]) {
        this.logger.debug?.('db_record_study_event_idempotent', {
          device_id: deviceId,
          client_event_id: event.client_event_id ?? null,
          event_id: event.event_id ?? null,
          elapsed_ms: Date.now() - startedAt
        });
        return {
          eventId: null,
          idempotent: true,
          proficiency: await this.#buildProficiencyResponse({ client, deviceId, userId, language })
        };
      }
      await this.#upsertWordState({
        client,
        deviceId,
        userId: eventUserId,
        language,
        event: inserted.rows[0]
      });

      // Practice games review words but never move the CEFR/HSK ladder.
      const levelChange = isGameSource(inserted.rows[0].source)
        ? null
        : await this.#applyProficiencyChange({
            client,
            deviceId,
            userId: eventUserId,
            language,
            rating: event.rating,
            occurredAt: inserted.rows[0].occurred_at,
            proficiency
          });

      this.logger.debug?.('db_record_study_event_completed', {
        device_id: deviceId,
        client_event_id: event.client_event_id ?? null,
        event_id: event.event_id ?? null,
        elapsed_ms: Date.now() - startedAt
      });
      return {
        eventId: inserted.rows[0].id,
        idempotent: false,
        proficiency: await this.#buildProficiencyResponse({
          client,
          deviceId,
          userId: eventUserId,
          language,
          ...levelChange
        })
      };
    });
  }

  async getProficiency({ deviceId, language = 'en', userId = null }) {
    return this.#buildProficiencyResponse({ deviceId, userId, language });
  }

  async getContentPipelineHealth() {
    const [articlesResult, memorizationResult, shadowingResult] = await Promise.all([
      this.pool.query(
        `SELECT
          COUNT(*) FILTER (WHERE status = 'pending_processing')::int AS pending_count,
          COUNT(*) FILTER (WHERE status = 'failed')::int AS failed_count,
          MAX(COALESCE(finished_at, updated_at)) AS last_processed_at
         FROM article_processing_jobs`
      ),
      this.pool.query(
        `SELECT
          COUNT(*) FILTER (WHERE status IN ('pending_segmentation', 'segmenting'))::int AS pending_count,
          COUNT(*) FILTER (WHERE status = 'failed' OR enrichment_status = 'failed')::int AS failed_count,
          MAX(updated_at) AS last_processed_at
         FROM memorization_passages`
      ),
      this.pool.query(
        `SELECT
          0::int AS pending_count,
          0::int AS failed_count,
          MAX(updated_at) AS last_processed_at
         FROM shadowing_videos`
      )
    ]);

    return {
      articles: rowToPipelineHealthSection(articlesResult.rows[0]),
      memorization: rowToPipelineHealthSection(memorizationResult.rows[0]),
      shadowing: rowToPipelineHealthSection(shadowingResult.rows[0]),
    };
  }

  async registerUser({ identifier, password, displayName = null, deviceId = null }) {
    const input = requireRegistrationInput({ identifier, password });
    return this.#withOptionalTransaction(async (client) => {
      const existing = await client.query(
        `SELECT * FROM users
        WHERE identifier = $1
        LIMIT 1`,
        [input.identifier]
      );
      if (existing.rows[0]) {
        throw new DuplicateUserError(input.identifier);
      }
      const now = new Date().toISOString();
      let inserted;
      try {
        inserted = await client.query(
          `INSERT INTO users (
            id,
            identifier,
            display_name,
            password_hash,
            created_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6)
          RETURNING *`,
          [createId('user'), input.identifier, displayName, await createPasswordHash(input.password), now, now]
        );
      } catch (error) {
        if (error?.code === '23505') {
          throw new DuplicateUserError(input.identifier);
        }
        throw error;
      }
      // Claim device-only word states and cached words for the new user
      await this.#claimDeviceWordStates({ client, userId: inserted.rows[0].id, deviceId });
      await this.#claimDeviceCachedWords({ client, userId: inserted.rows[0].id, deviceId });
      await this.#claimDeviceActivity({ client, userId: inserted.rows[0].id, deviceId });
      const sessionResult = await this.#createSessionForUser({
        client,
        user: inserted.rows[0],
        deviceId
      });
      return { user: inserted.rows[0], ...sessionResult };
    });
  }

  async createUserSession({ identifier, password, deviceId = null }) {
    const normalizedIdentifier = normalizeUserIdentifier(identifier);
    const userResult = await this.pool.query(
      `SELECT * FROM users
      WHERE identifier = $1
      LIMIT 1`,
      [normalizedIdentifier]
    );
    const user = userResult.rows[0];
    if (!user) {
      throw new InvalidCredentialsError({ reason: 'user_not_found' });
    }
    if (!await verifyPassword(password, user.password_hash)) {
      throw new InvalidCredentialsError();
    }
    return this.#withOptionalTransaction(async (client) => {
      // Claim device-only word states and cached words for the signing-in user
      await this.#claimDeviceWordStates({ client, userId: user.id, deviceId });
      await this.#claimDeviceCachedWords({ client, userId: user.id, deviceId });
      await this.#claimDeviceActivity({ client, userId: user.id, deviceId });
      const sessionResult = await this.#createSessionForUser({
        client,
        user,
        deviceId
      });
      return { user, ...sessionResult };
    });
  }

  async resolveUserSession({ sessionToken }) {
    if (!sessionToken) {
      return null;
    }
    const result = await this.pool.query(
      `SELECT
        user_sessions.*,
        users.identifier,
        users.display_name
      FROM user_sessions
      JOIN users ON users.id = user_sessions.user_id
      WHERE token_hash = $1 AND revoked_at IS NULL
      LIMIT 1`,
      [hashSessionToken(sessionToken)]
    );
    const row = result.rows[0];
    if (!row) {
      return null;
    }
    return {
      session: {
        id: row.id,
        user_id: row.user_id,
        token_hash: row.token_hash,
        device_id: row.device_id,
        created_at: row.created_at,
        revoked_at: row.revoked_at
      },
      user: {
        id: row.user_id,
        identifier: row.identifier,
        display_name: row.display_name
      }
    };
  }

  async revokeUserSession({ sessionToken }) {
    const result = await this.pool.query(
      `UPDATE user_sessions
      SET revoked_at = $2
      WHERE token_hash = $1 AND revoked_at IS NULL
      RETURNING *`,
      [hashSessionToken(sessionToken), new Date().toISOString()]
    );
    return { revoked: result.rows.length > 0 };
  }

  async getArticleVocabulary({ articleId, userId }) {
    if (!userId) {
      return null;
    }
    const result = await this.pool.query(
      `SELECT
        articles.id AS article_id,
        articles.owner_user_id,
        articles.visibility,
        articles.status,
        article_terms.id AS article_term_id,
        article_terms.created_at AS article_term_created_at,
        terms.id AS term_id,
        terms.display_term,
        words.id AS word_id,
        word_senses.id AS word_sense_id,
        word_senses.meaning_vi,
        word_senses.part_of_speech,
        word_senses.ipa,
        word_senses.level,
        word_senses.status AS word_sense_status,
        article_terms.classification AS article_term_classification,
        article_terms.suggestion_type AS article_term_suggestion_type,
        speaking_prompt.id AS speaking_prompt_id,
        speaking_prompt.target_text AS speaking_prompt_target_text,
        speaking_prompt.vi_hint AS speaking_prompt_vi_hint,
        speaking_prompt.target_phrase AS speaking_prompt_target_phrase,
        speaking_prompt.pronunciation_tip_vi AS speaking_prompt_pronunciation_tip_vi,
        speaking_prompt.common_mistake_vi AS speaking_prompt_common_mistake_vi,
        speaking_prompt.difficulty AS speaking_prompt_difficulty,
        speaking_prompt.topic AS speaking_prompt_topic
      FROM articles
      JOIN article_terms ON article_terms.article_id = articles.id
      JOIN terms ON terms.id = article_terms.term_id
      JOIN word_senses ON word_senses.id = article_terms.word_sense_id
      LEFT JOIN words ON words.language = terms.language AND words.normalized_term = terms.normalized_term
      LEFT JOIN LATERAL (
        SELECT * FROM speaking_prompts
        WHERE speaking_prompts.word_sense_id = word_senses.id
          AND speaking_prompts.status = 'approved'
        ORDER BY speaking_prompts.updated_at DESC, speaking_prompts.id ASC
        LIMIT 1
      ) speaking_prompt ON true
      WHERE articles.id = $1
        AND articles.status <> 'deleted'
        AND (
          articles.owner_user_id = $2
          OR articles.visibility = 'published'
        )
        AND (
          articles.visibility <> 'published'
          OR word_senses.status = 'approved'
        )
      ORDER BY article_terms.created_at ASC, article_terms.id ASC`,
      [articleId, userId]
    );
    if (result.rows.length === 0) {
      const accessCheck = await this.pool.query(
        `SELECT id FROM articles
        WHERE id = $1 AND status <> 'deleted'
          AND (owner_user_id = $2 OR visibility = 'published')
        LIMIT 1`,
        [articleId, userId]
      );
      if (!accessCheck.rows[0]) {
        return null;
      }
      return { article_id: accessCheck.rows[0].id, items: [] };
    }

    // The study word behind each term, so the app can add it to the learner's reviews.
    const wordIds = [...new Set(result.rows.map((row) => row.word_id).filter(Boolean))];
    const words = wordIds.length ? await this.pool.query(`SELECT * FROM words WHERE id = ANY($1)`, [wordIds]) : { rows: [] };
    const wordById = new Map(words.rows.map((row) => [row.id, toApiWord(rowToWord(row))]));
    return {
      article_id: result.rows[0].article_id,
      items: result.rows.map((row) => ({
        term_id: row.term_id,
        display_term: row.display_term,
        word: wordById.get(row.word_id) ?? null,
        word_sense_id: row.word_sense_id,
        meaning_vi: row.meaning_vi,
        part_of_speech: row.part_of_speech,
        ipa: row.ipa,
        level: row.level,
        status: row.word_sense_status,
        classification: row.article_term_classification ?? null,
        suggestion_type: row.article_term_suggestion_type ?? null,
        speaking_prompt: row.speaking_prompt_id
          ? toApiSpeakingPrompt({
              id: row.speaking_prompt_id,
              target_text: row.speaking_prompt_target_text,
              vi_hint: row.speaking_prompt_vi_hint,
              target_phrase: row.speaking_prompt_target_phrase,
              pronunciation_tip_vi: row.speaking_prompt_pronunciation_tip_vi,
              common_mistake_vi: row.speaking_prompt_common_mistake_vi,
              difficulty: row.speaking_prompt_difficulty,
              topic: row.speaking_prompt_topic
            })
          : null
      }))
    };
  }

  async softDeleteArticle({ articleId, userId }) {
    const result = await this.pool.query(
      `UPDATE articles
      SET status = 'deleted', visibility = 'private', updated_at = $3
      WHERE id = $1 AND owner_user_id = $2 AND status <> 'deleted'
      RETURNING *`,
      [articleId, userId, new Date().toISOString()]
    );
    return result.rows[0] ?? null;
  }

  async patchAdminArticle({ articleId, patch }) {
    const assignments = [];
    const values = [articleId];
    for (const field of ADMIN_ARTICLE_PATCH_FIELDS) {
      if (patch[field] !== undefined) {
        values.push(patch[field]);
        assignments.push(`${field} = $${values.length}`);
      }
    }
    if (assignments.length === 0) {
      const existing = await this.pool.query(`SELECT * FROM articles WHERE id = $1 LIMIT 1`, [articleId]);
      return existing.rows[0] ?? null;
    }
    values.push(new Date().toISOString());
    assignments.push(`updated_at = $${values.length}`);
    const result = await this.pool.query(
      `UPDATE articles
      SET ${assignments.join(', ')}
      WHERE id = $1
      RETURNING *`,
      values
    );
    return result.rows[0] ?? null;
  }

  async healthCheck() {
    await this.pool.query('SELECT 1');
    return true;
  }

  async getOrInitializeProficiency({ deviceId, userId = null, language = 'en', client = this.pool }) {
    const existing = userId
      ? await client.query(
          `SELECT * FROM user_proficiency
          WHERE user_id = $1 AND language = $2
          LIMIT 1`,
          [userId, language]
        )
      : await client.query(
          `SELECT * FROM user_proficiency
          WHERE device_id = $1 AND language = $2
          LIMIT 1`,
          [deviceId, language]
        );
    if (existing.rows[0]) {
      return existing.rows[0];
    }

    const now = new Date().toISOString();
    const conflictTarget = userId
      ? '(user_id, language) WHERE user_id IS NOT NULL'
      : '(device_id, language) WHERE user_id IS NULL';
    const inserted = await client.query(
      `INSERT INTO user_proficiency (
        id,
        user_id,
        device_id,
        language,
        level,
        created_at,
        updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT ${conflictTarget} DO UPDATE SET updated_at = user_proficiency.updated_at
      RETURNING *`,
      [createId('proficiency'), userId, deviceId, language, getDefaultProficiencyLevel({ language }), now, now]
    );
    return inserted.rows[0];
  }

  async #applyProficiencyChange({ client, deviceId, userId = null, language, rating, occurredAt, proficiency }) {
    const change = planLevelChange({
      rating,
      recentEvents: await this.#recentEvents({ deviceId, userId, client }),
      levelChangedAt: proficiency.level_changed_at ?? null,
      currentLevel: proficiency.level,
      language
    });
    if (change) {
      await client.query(
        `UPDATE user_proficiency
        SET level = $3, updated_at = $4, level_changed_at = $5
        WHERE ${userId ? 'user_id' : 'device_id'} = $1 AND language = $2`,
        [userId ?? deviceId, language, change.nextLevel, new Date().toISOString(), occurredAt]
      );
    }
    return change;
  }

  async #buildProficiencyResponse({ deviceId, userId = null, language = 'en', client = this.pool, ...levelChange } = {}) {
    return toProficiencyResponse({
      proficiency: await this.getOrInitializeProficiency({ deviceId, userId, language, client }),
      recentEvents: await this.#recentEvents({ deviceId, userId, client }),
      userId,
      language,
      ...levelChange
    });
  }

  async #recentEvents({ deviceId, userId = null, client = this.pool }) {
    const result = userId
      ? await client.query(
          `SELECT * FROM study_events
          WHERE user_id = $1 AND (source IS NULL OR source NOT LIKE 'game\\_%')
          ORDER BY occurred_at DESC, received_at DESC, id DESC
          LIMIT 10`,
          [userId]
        )
      : await client.query(
          `SELECT * FROM study_events
          WHERE device_id = $1 AND (source IS NULL OR source NOT LIKE 'game\\_%')
          ORDER BY occurred_at DESC, received_at DESC, id DESC
          LIMIT 10`,
          [deviceId]
        );
    return result.rows;
  }

  async createArticle({ userId, title, sourceUrl = null, language, rawText, visibility = 'private' }) {
    return this.#insertArticle({ ownerUserId: userId, adminUserId: null, title, sourceUrl, language, rawText, visibility });
  }

  async listArticles({ userId, limit = 50 }) {
    const result = await this.pool.query(
      `SELECT * FROM articles
      WHERE (owner_user_id = $1 OR (visibility = 'published' AND status = 'published'))
        AND status <> 'deleted'
      ORDER BY created_at DESC
      LIMIT $2`,
      [userId, clampLimit(limit, 100)]
    );
    return result.rows;
  }

  async getArticleByIdForUser({ articleId, userId }) {
    const result = await this.pool.query(
      `SELECT * FROM articles
      WHERE id = $1
        AND (owner_user_id = $2 OR (visibility = 'published' AND status = 'published'))
        AND status <> 'deleted'
      LIMIT 1`,
      [articleId, userId]
    );
    return result.rows[0] ?? null;
  }

  async getArticleById({ articleId }) {
    const result = await this.pool.query(`SELECT * FROM articles WHERE id = $1 LIMIT 1`, [articleId]);
    return result.rows[0] ?? null;
  }

  async createAdminArticle({
    adminUserId = null,
    title,
    sourceUrl = null,
    language,
    rawText,
    visibility = 'published'
  }) {
    return this.#insertArticle({ ownerUserId: null, adminUserId, title, sourceUrl, language, rawText, visibility });
  }

  async listAdminArticles({ limit = 50, status = null }) {
    const result = await this.pool.query(
      `SELECT * FROM articles
      WHERE ($1::text IS NULL OR status = $1)
      ORDER BY created_at DESC
      LIMIT $2`,
      [status, clampLimit(limit, 100)]
    );
    return result.rows;
  }

  async reprocessArticle({ articleId }) {
    const result = await this.pool.query(
      `UPDATE articles
      SET status = 'pending_processing', processing_error = NULL, updated_at = $2
      WHERE id = $1
      RETURNING *`,
      [articleId, new Date().toISOString()]
    );
    const article = result.rows[0] ?? null;
    if (!article) {
      return null;
    }
    await this.pool.query(`DELETE FROM article_workplace_sentences WHERE article_id = $1`, [articleId]);
    await this.pool.query(
      `DELETE FROM workplace_sentences
      WHERE id NOT IN (SELECT workplace_sentence_id FROM article_workplace_sentences)`
    );
    await this.enqueueArticleProcessingJob({ articleId: article.id });
    return article;
  }

  async publishArticle({ articleId }) {
    const result = await this.pool.query(
      `UPDATE articles
      SET status = 'published', visibility = 'published', updated_at = $2
      WHERE id = $1
      RETURNING *`,
      [articleId, new Date().toISOString()]
    );
    return result.rows[0] ?? null;
  }

  async listVocabularyReviewItems({ status = 'pending', limit = 100 }) {
    const result = await this.pool.query(
      `SELECT * FROM vocabulary_review_items
      WHERE status = $1
      ORDER BY created_at DESC
      LIMIT $2`,
      [status, clampLimit(limit, 200)]
    );
    return result.rows;
  }

  async reviewVocabularyItem({ itemId, status, reviewNote = null, reviewerUserId = null }) {
    const now = new Date().toISOString();
    // Update the review item and sync word_senses.status so that
    // getArticleVocabulary visibility filtering (word_senses.status = 'approved')
    // reflects the admin decision. Mirrors InMemory WordStore behaviour.
    const senseStatus = status === 'approved' ? 'approved' : 'rejected';
    const result = await this.#withOptionalTransaction(async (client) => {
      const itemResult = await client.query(
        `UPDATE vocabulary_review_items
        SET status = $2,
            review_note = $3,
            reviewer_user_id = $4,
            reviewed_at = $5,
            updated_at = $5
        WHERE id = $1
        RETURNING *`,
        [itemId, status, reviewNote, reviewerUserId, now]
      );
      const item = itemResult.rows[0];
      if (!item) {
        return null;
      }
      await client.query(`UPDATE word_senses SET status = $1, updated_at = $2 WHERE id = $3`, [
        senseStatus,
        now,
        item.word_sense_id
      ]);
      return item;
    });
    return result;
  }

  async listContentPacks({ language = 'en', afterVersion = null, limit = 100 }) {
    const result = await this.pool.query(
      `SELECT * FROM content_packs
      WHERE status = 'published' AND language = $1
        AND ($2::int IS NULL OR version > $2)
      ORDER BY version DESC
      LIMIT $3`,
      [language, afterVersion, clampLimit(limit, 200)]
    );
    return result.rows;
  }

  async getContentPackById({ id }) {
    const packResult = await this.pool.query(
      `SELECT * FROM content_packs
      WHERE id = $1 AND status = 'published'
      LIMIT 1`,
      [id]
    );
    const pack = packResult.rows[0];
    if (!pack) {
      return null;
    }

    const items = await this.pool.query(
      `SELECT cpi.id, cpi.word_sense_id, cpi.created_at
      FROM content_pack_items cpi
      JOIN word_senses ws ON ws.id = cpi.word_sense_id
      WHERE cpi.content_pack_id = $1 AND ws.status = 'approved'
      ORDER BY cpi.created_at ASC`,
      [id]
    );

    return {
      ...pack,
      items: items.rows
    };
  }

  async enqueueArticleProcessingJob({ articleId }) {
    const now = new Date().toISOString();
    const result = await this.pool.query(
      `INSERT INTO article_processing_jobs (
        id,
        article_id,
        status,
        attempt_count,
        queued_at,
        started_at,
        finished_at,
        error_message,
        created_at,
        updated_at
      )
      VALUES ($1, $2, 'pending_processing', 0, $3, NULL, NULL, NULL, $3, $3)
      RETURNING *`,
      [createId('article_job'), articleId, now]
    );
    return result.rows[0];
  }

  async claimNextArticleProcessingJob() {
    return this.#withOptionalTransaction(async (client) => {
      const now = new Date().toISOString();
      const updated = await client.query(
        `UPDATE article_processing_jobs
        SET status = 'processing',
            attempt_count = attempt_count + 1,
            started_at = $1,
            updated_at = $1
        WHERE id = (
          SELECT id FROM article_processing_jobs
          WHERE status = 'pending_processing'
            OR (status = 'processing' AND started_at < $2)
          ORDER BY queued_at ASC
          LIMIT 1
          FOR UPDATE SKIP LOCKED
        )
        RETURNING *`,
        // Jobs stranded in 'processing' by a dead worker (deploy/restart) are reclaimed after a timeout.
        [now, staleArticleJobCutoff()]
      );
      const job = updated.rows[0];
      if (!job) {
        return null;
      }
      await client.query(
        `UPDATE articles
        SET status = CASE WHEN status = 'deleted' THEN status ELSE 'processing' END,
            updated_at = CASE WHEN status = 'deleted' THEN updated_at ELSE $2 END
        WHERE id = $1`,
        [job.article_id, now]
      );
      return job;
    });
  }

  async completeArticleProcessingJob({ jobId, status = 'processed', errorMessage = null }) {
    return this.#withOptionalTransaction(async (client) => {
      const now = new Date().toISOString();
      const updated = await client.query(
        `UPDATE article_processing_jobs
        SET status = $2,
            error_message = $3,
            finished_at = $4,
            updated_at = $4
        WHERE id = $1
        RETURNING *`,
        [jobId, status, errorMessage, now]
      );
      const job = updated.rows[0];
      if (!job) {
        return null;
      }
      await client.query(
        `UPDATE articles
        SET status = CASE WHEN status = 'deleted' THEN status ELSE $2 END,
            processing_error = CASE WHEN status = 'deleted' THEN processing_error ELSE $3 END,
            updated_at = CASE WHEN status = 'deleted' THEN updated_at ELSE $4 END
        WHERE id = $1`,
        [job.article_id, status, errorMessage, now]
      );
      return job;
    });
  }

  async countPendingArticleJobs() {
    const result = await this.pool.query(
      `SELECT COUNT(*) AS count FROM article_processing_jobs WHERE status = 'pending_processing'`
    );
    return Number(result.rows[0]?.count ?? 0);
  }

  /**
   * Stores the term, a new sense, its link row (via `insertLinkRow`) and its
   * review item for an extracted vocabulary item; approved items are also
   * bridged into the words pool.
   */
  async #persistVocabularyItem({ client, item, normalized, requiresReview, now, insertLinkRow, reviewArticleId, bridgedWord }) {
    const { senseStatus, reviewStatus, reviewedAt } = reviewStatuses(requiresReview, now);
    const termResult = await client.query(
      `INSERT INTO terms (id, language, display_term, normalized_term, lemma, created_at)
      VALUES ($1, $2, $3, $4, NULL, $5)
      ON CONFLICT (language, normalized_term) DO UPDATE SET display_term = EXCLUDED.display_term
      RETURNING *`,
      [createId('term'), item.language, item.term, normalized, now]
    );
    const term = termResult.rows[0];

    const fields = senseFieldsFromItem(item);
    const senseResult = await client.query(
      `INSERT INTO word_senses (
        id, term_id, part_of_speech, meaning_vi, short_definition,
        pronunciation, ipa, pinyin, level_scale, level,
        quality_score, status, created_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $13)
      RETURNING *`,
      [
        createId('sense'),
        term.id,
        fields.part_of_speech,
        fields.meaning_vi,
        fields.short_definition,
        fields.pronunciation,
        fields.ipa,
        fields.pinyin,
        fields.level_scale,
        fields.level,
        fields.quality_score,
        senseStatus,
        now,
      ]
    );
    const sense = senseResult.rows[0];

    await insertLinkRow(client, term.id, sense.id);

    await client.query(
      `INSERT INTO vocabulary_review_items (
        id, word_sense_id, article_id, status,
        reviewer_user_id, review_note, reviewed_at, created_at, updated_at
      )
      VALUES ($1, $2, $3, $4, NULL, NULL, $5, $6, $6)`,
      [createId('review_item'), sense.id, reviewArticleId ?? null, reviewStatus, reviewedAt, now]
    );

    if (!requiresReview) {
      const word = bridgedWordInput(item, bridgedWord);
      await client.query(
        `INSERT INTO words (
          id, term, normalized_term, language, meaning_vi,
          part_of_speech, ipa, vietnamese_pronunciation,
          example, example_vi, difficulty, topics_json,
          generation_source, created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $14)
        ON CONFLICT (language, normalized_term) DO NOTHING`,
        [
          createId('word'),
          word.term,
          normalized,
          word.language,
          word.meaning_vi,
          word.part_of_speech,
          word.ipa,
          word.vietnamese_pronunciation,
          word.example,
          word.example_vi,
          word.difficulty,
          JSON.stringify(word.topics),
          word.generation_source,
          now,
        ]
      );
    }
  }

  async persistArticleVocabulary({ articleId, items = [] }) {
    return this.#withOptionalTransaction(async (client) => {
      const articleResult = await client.query(`SELECT * FROM articles WHERE id = $1 LIMIT 1 FOR UPDATE`, [articleId]);
      const article = articleResult.rows[0];
      if (!article) {
        throw new Error('article_not_found');
      }

      // Delete existing vocabulary for this article to prevent duplicates on reprocess
      const existingTermsResult = await client.query(`SELECT word_sense_id FROM article_terms WHERE article_id = $1`, [
        articleId
      ]);
      const oldSenseIds = existingTermsResult.rows.map((r) => r.word_sense_id);
      await client.query(`DELETE FROM vocabulary_review_items WHERE article_id = $1`, [articleId]);
      await client.query(`DELETE FROM article_terms WHERE article_id = $1`, [articleId]);
      await client.query(`DELETE FROM article_workplace_sentences WHERE article_id = $1`, [articleId]);
      await client.query(
        `DELETE FROM workplace_sentences WHERE id NOT IN (SELECT workplace_sentence_id FROM article_workplace_sentences)`
      );
      if (oldSenseIds.length > 0) {
        await client.query(`DELETE FROM word_senses WHERE id = ANY($1)`, [oldSenseIds]);
      }

      const now = new Date().toISOString();
      let persistedCount = 0;
      const seen = new Set();

      for (const item of items) {
        const normalized = normalizeTerm(item.term);
        const dedupeKey = `${item.language}:${normalized}`;
        if (seen.has(dedupeKey)) {
          continue;
        }
        seen.add(dedupeKey);
        const suggestionType = normalizeSuggestionType(item.suggestion_type, item.term);
        await this.#persistVocabularyItem({
          client,
          item,
          normalized,
          requiresReview: articleItemRequiresReview(article, item),
          now,
          insertLinkRow: async (c, termId, senseId) => {
            await c.query(
              `INSERT INTO article_terms (
                id, article_id, term_id, word_sense_id, surface_text,
                sentence_context, start_offset, end_offset, frequency, extraction_confidence,
                classification, suggestion_type, created_at
              )
              VALUES ($1, $2, $3, $4, $5, $6, NULL, NULL, $7, $8, $9, $10, $11)`,
              [
                createId('article_term'),
                articleId,
                termId,
                senseId,
                item.term,
                item.example ?? null,
                Number(item.frequency ?? 1),
                Number(item.confidence ?? 0.5),
                item.classification ?? null,
                suggestionType,
                now,
              ]
            );
          },
          reviewArticleId: articleId,
          bridgedWord: { example: item.example ?? '', topics: [], generationSource: 'article_vocabulary' }
        });
        persistedCount += 1;
      }

      return { count: persistedCount };
    });
  }

  async persistPassageVocabulary({ passageId, items = [] }) {
    return this.#withOptionalTransaction(async (client) => {
      const passageResult = await client.query(
        `SELECT * FROM memorization_passages WHERE id = $1 LIMIT 1 FOR UPDATE`,
        [passageId]
      );
      const passage = passageResult.rows[0];
      if (!passage) {
        throw new Error('passage_not_found');
      }

      const existingTermsResult = await client.query(
        `SELECT word_sense_id FROM memorization_segment_terms WHERE passage_id = $1`,
        [passageId]
      );
      const oldSenseIds = existingTermsResult.rows.map((row) => row.word_sense_id).filter(Boolean);
      if (oldSenseIds.length > 0) {
        await client.query(`DELETE FROM vocabulary_review_items WHERE word_sense_id = ANY($1)`, [oldSenseIds]);
      }
      await client.query(`DELETE FROM memorization_segment_terms WHERE passage_id = $1`, [passageId]);
      if (oldSenseIds.length > 0) {
        await client.query(`DELETE FROM word_senses WHERE id = ANY($1)`, [oldSenseIds]);
      }

      const segmentsResult = await client.query(
        `SELECT id, text FROM memorization_segments WHERE passage_id = $1`,
        [passageId]
      );
      const segmentById = new Map(segmentsResult.rows.map((segment) => [segment.id, segment]));
      const now = new Date().toISOString();
      const requiresReview = passageRequiresReview(passage);
      const seen = new Set();
      let persistedCount = 0;

      for (const item of items) {
        const segment = segmentById.get(item.segment_id);
        if (!segment) {
          continue;
        }
        const normalized = normalizeTerm(item.term);
        if (!normalized) {
          continue;
        }
        const dedupeKey = `${item.segment_id}:${item.language}:${normalized}`;
        if (seen.has(dedupeKey)) {
          continue;
        }
        seen.add(dedupeKey);

        const suggestionType = normalizeSuggestionType(item.suggestion_type, item.term);
        await this.#persistVocabularyItem({
          client,
          item,
          normalized,
          requiresReview,
          now,
          insertLinkRow: async (c, termId, senseId) => {
            await c.query(
              `INSERT INTO memorization_segment_terms (
                id, passage_id, segment_id, term_id, word_sense_id, surface_text,
                sentence_context, frequency, extraction_confidence, classification,
                suggestion_type, created_at
              )
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
              [
                createId('segment_term'),
                passageId,
                item.segment_id,
                termId,
                senseId,
                item.term,
                item.example ?? segment.text,
                Number(item.frequency ?? 1),
                Number(item.confidence ?? 0.5),
                item.classification ?? null,
                suggestionType,
                now,
              ]
            );
          },
          reviewArticleId: null,
          bridgedWord: {
            example: item.example ?? segment.text,
            topics: ['memorization'],
            generationSource: 'memorization_passage_vocabulary'
          }
        });
        persistedCount += 1;
      }

      return { count: persistedCount };
    });
  }

  async persistArticleWorkplaceSentences({ articleId, items = [] }) {
    return this.#withOptionalTransaction(async (client) => {
      const articleResult = await client.query(`SELECT * FROM articles WHERE id = $1 LIMIT 1 FOR UPDATE`, [articleId]);
      const article = articleResult.rows[0];
      if (!article) {
        throw new Error('article_not_found');
      }

      await client.query(`DELETE FROM article_workplace_sentences WHERE article_id = $1`, [articleId]);
      await client.query(
        `DELETE FROM workplace_sentences
        WHERE id NOT IN (SELECT workplace_sentence_id FROM article_workplace_sentences)`
      );

      const now = new Date().toISOString();
      let persistedCount = 0;
      const seen = new Set();

      for (const item of items) {
        const normalizedText = normalizeSentenceText(item.text);
        const dedupeKey = `${item.language}:${normalizedText}`;
        if (!normalizedText || seen.has(dedupeKey)) {
          continue;
        }
        seen.add(dedupeKey);

        const result = await client.query(
          `INSERT INTO workplace_sentences (
            id,
            text,
            normalized_text,
            language,
            meaning_vi,
            topic,
            generation_source,
            created_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8)
          ON CONFLICT (language, normalized_text) DO UPDATE
          SET meaning_vi = EXCLUDED.meaning_vi,
              topic = COALESCE(EXCLUDED.topic, workplace_sentences.topic),
              updated_at = EXCLUDED.updated_at
          RETURNING *`,
          [
            createId('sentence'),
            item.text,
            normalizedText,
            item.language,
            item.meaning_vi,
            item.topic ?? null,
            item.generation_source ?? 'article_workplace_sentence',
            now
          ]
        );

        const sentence = result.rows[0];
        await client.query(
          `INSERT INTO article_workplace_sentences (
            id,
            article_id,
            workplace_sentence_id,
            created_at
          )
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (article_id, workplace_sentence_id) DO NOTHING`,
          [createId('article_sentence'), articleId, sentence.id, now]
        );
        persistedCount += 1;
      }

      return { count: persistedCount };
    });
  }

  async #insertArticle(fields) {
    const article = buildArticle(fields);
    const result = await this.pool.query(
      `INSERT INTO articles (
        id, owner_user_id, created_by_admin_id,
        title, source_url, language, raw_text, cleaned_text,
        visibility, status, processing_error, created_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *`,
      [
        article.id,
        article.owner_user_id,
        article.created_by_admin_id,
        article.title,
        article.source_url,
        article.language,
        article.raw_text,
        article.cleaned_text,
        article.visibility,
        article.status,
        article.processing_error,
        article.created_at,
        article.updated_at
      ]
    );
    const inserted = result.rows[0];
    await this.enqueueArticleProcessingJob({ articleId: inserted.id });
    return inserted;
  }

  async #cachedWordIdsForSelection({ deviceId, userId = null }) {
    if (!userId) {
      return this.cachedWordIdsFor({ deviceId });
    }
    const [userCached, deviceCached] = await Promise.all([
      this.cachedWordIdsFor({ deviceId, userId }),
      this.cachedWordIdsFor({ deviceId, userId: null })
    ]);
    return new Set([...userCached, ...deviceCached]);
  }

  /** Recomputes every stored word state from its events (src/rebuild_srs_states.js). Returns the count. */
  async rebuildWordStates() {
    const states = await this.pool.query(`SELECT user_id, device_id, word_id, language FROM user_word_states`);
    for (const state of states.rows) {
      await this.#upsertWordState({
        client: this.pool,
        deviceId: state.device_id,
        userId: state.user_id,
        language: state.language,
        event: { word_id: state.word_id }
      });
    }
    return states.rows.length;
  }

  /**
   * Rebuilds the owner's SRS state for the event's word from every rated event of that word, so an
   * offline device uploading older events late can never overwrite newer progress.
   */
  async #upsertWordState({ client, deviceId, userId = null, language, event }) {
    if (!event.word_id) {
      return;
    }
    const events = await client.query(
      userId
        ? `SELECT rating, occurred_at, client_event_id FROM study_events WHERE user_id = $1 AND word_id = $2`
        : `SELECT rating, occurred_at, client_event_id FROM study_events
          WHERE device_id = $1 AND user_id IS NULL AND word_id = $2`,
      [userId ?? deviceId, event.word_id]
    );
    const state = replaySrsState(events.rows);
    if (!state) {
      return;
    }
    const owner = userId ? '(user_id, word_id) WHERE user_id IS NOT NULL' : '(device_id, word_id) WHERE user_id IS NULL';
    await client.query(
      `INSERT INTO user_word_states (
        id, user_id, device_id, word_id, language, status, last_rating, last_studied_at, next_review_at,
        ease_factor, interval_days, reps, lapses, review_count, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
      ON CONFLICT ${owner}
      DO UPDATE SET
        device_id = EXCLUDED.device_id,
        language = EXCLUDED.language,
        status = EXCLUDED.status,
        last_rating = EXCLUDED.last_rating,
        last_studied_at = EXCLUDED.last_studied_at,
        next_review_at = EXCLUDED.next_review_at,
        ease_factor = EXCLUDED.ease_factor,
        interval_days = EXCLUDED.interval_days,
        reps = EXCLUDED.reps,
        lapses = EXCLUDED.lapses,
        review_count = EXCLUDED.review_count,
        updated_at = EXCLUDED.updated_at`,
      [
        createId('word_state'),
        userId,
        deviceId,
        event.word_id,
        language,
        state.status,
        state.last_rating,
        state.last_studied_at,
        state.next_review_at,
        state.ease_factor,
        state.interval_days,
        state.reps,
        state.lapses,
        state.review_count,
        new Date().toISOString()
      ]
    );
  }

  async #createSessionForUser({ client, user, deviceId = null }) {
    const now = new Date().toISOString();
    const sessionToken = createSessionToken();
    const inserted = await client.query(
      `INSERT INTO user_sessions (
        id,
        user_id,
        token_hash,
        device_id,
        created_at,
        revoked_at
      )
      VALUES ($1, $2, $3, $4, $5, NULL)
      RETURNING *`,
      [createId('session'), user.id, hashSessionToken(sessionToken), deviceId, now]
    );
    return {
      session: inserted.rows[0],
      sessionToken
    };
  }

  // Attach study/speaking history and proficiency recorded on this device
  // before sign-in (including offline events synced anonymously) to the user.
  async #claimDeviceActivity({ client, userId, deviceId }) {
    if (!deviceId) return;
    await client.query('UPDATE study_events SET user_id = $1 WHERE device_id = $2 AND user_id IS NULL', [
      userId,
      deviceId
    ]);
    await client.query('UPDATE speaking_events SET user_id = $1 WHERE device_id = $2 AND user_id IS NULL', [
      userId,
      deviceId
    ]);
    await client.query('UPDATE game_rounds SET user_id = $1 WHERE device_id = $2 AND user_id IS NULL', [
      userId,
      deviceId
    ]);
    await client.query(
      `UPDATE user_proficiency device_row
       SET user_id = $1
       WHERE device_row.device_id = $2
         AND device_row.user_id IS NULL
         AND NOT EXISTS (
           SELECT 1 FROM user_proficiency user_row
           WHERE user_row.user_id = $1 AND user_row.language = device_row.language
         )`,
      [userId, deviceId]
    );
  }

  async #claimDeviceWordStates({ client, userId, deviceId }) {
    if (!deviceId) return { claimed: 0, conflicts: 0 };

    // Step 1: Delete device-only rows that conflict with existing user rows
    // (keep the "better" one based on review_count then last_studied_at)
    const deleteConflicts = await client.query(
      `DELETE FROM user_word_states AS device_state
       USING user_word_states AS user_state
       WHERE device_state.device_id = $1
         AND device_state.user_id IS NULL
         AND user_state.user_id = $2
         AND device_state.word_id = user_state.word_id
         AND (
           user_state.review_count > device_state.review_count
           OR (
             user_state.review_count = device_state.review_count
             AND COALESCE(user_state.last_studied_at, '') >= COALESCE(device_state.last_studied_at, '')
           )
         )`,
      [deviceId, userId]
    );

    // Step 2: Delete user rows that lose to device-only rows (device has better state)
    const deleteUserLosers = await client.query(
      `DELETE FROM user_word_states AS user_state
       USING user_word_states AS device_state
       WHERE device_state.device_id = $1
         AND device_state.user_id IS NULL
         AND user_state.user_id = $2
         AND device_state.word_id = user_state.word_id
         AND (
           device_state.review_count > user_state.review_count
           OR (
             device_state.review_count = user_state.review_count
             AND COALESCE(device_state.last_studied_at, '') > COALESCE(user_state.last_studied_at, '')
           )
         )`,
      [deviceId, userId]
    );

    // Step 3: Claim remaining device-only rows (no conflict or device won)
    const claimed = await client.query(
      `UPDATE user_word_states
       SET user_id = $2
       WHERE device_id = $1
         AND user_id IS NULL`,
      [deviceId, userId]
    );

    const conflicts = deleteConflicts.rowCount + deleteUserLosers.rowCount;
    return { claimed: claimed.rowCount, conflicts };
  }

  async #claimDeviceCachedWords({ client, userId, deviceId }) {
    if (!deviceId) return { claimed: 0, duplicatesRemoved: 0 };

    // Step 1: Delete device-only cached words that duplicate existing user cached words
    const deleteDuplicates = await client.query(
      `DELETE FROM user_cached_words AS device_row
       USING user_cached_words AS user_row
       WHERE device_row.device_id = $1
         AND device_row.user_id IS NULL
         AND user_row.user_id = $2
         AND device_row.word_id = user_row.word_id`,
      [deviceId, userId]
    );

    // Step 2: Claim remaining device-only cached words
    const claimed = await client.query(
      `UPDATE user_cached_words
       SET user_id = $2
       WHERE device_id = $1
         AND user_id IS NULL`,
      [deviceId, userId]
    );

    return { claimed: claimed.rowCount, duplicatesRemoved: deleteDuplicates.rowCount };
  }

  async #withOptionalTransaction(work) {
    return withOptionalTransaction(this, work);
  }

  async #hydrateSubmittedWord(client, submission) {
    if (!submission?.resolved_word_id) {
      return {
        ...submission,
        resolved_word: null
      };
    }

    const resolvedWordResult = await client.query(`SELECT * FROM words WHERE id = $1 LIMIT 1`, [submission.resolved_word_id]);
    return {
      ...submission,
      resolved_word: resolvedWordResult.rows[0] ? rowToWord(resolvedWordResult.rows[0]) : null
    };
  }

  async #hydrateSubmittedWords(client, submissions) {
    const resolvedIds = [...new Set(submissions.map((submission) => submission.resolved_word_id).filter(Boolean))];
    if (resolvedIds.length === 0) {
      return submissions.map((submission) => ({
        ...submission,
        resolved_word: null
      }));
    }

    const resolvedWordsResult = await client.query(`SELECT * FROM words WHERE id = ANY($1)`, [resolvedIds]);
    const resolvedWordById = new Map(resolvedWordsResult.rows.map((row) => [row.id, rowToWord(row)]));
    return submissions.map((submission) => ({
      ...submission,
      resolved_word: submission.resolved_word_id ? resolvedWordById.get(submission.resolved_word_id) ?? null : null
    }));
  }
}

mixinMethods(PostgresWordStore, PostgresSpeakingMethods, PostgresGameMethods, PostgresExamMethods, PostgresShadowingMethods, PostgresMemorizationMethods);

function rowToPipelineHealthSection(row = {}) {
  return {
    pending_count: Number(row?.pending_count ?? 0),
    failed_count: Number(row?.failed_count ?? 0),
    last_processed_at: row?.last_processed_at ?? null
  };
}

function rowToWord(row) {
  return {
    id: row.id,
    term: row.term,
    normalized_term: row.normalized_term,
    language: row.language,
    meaning_vi: row.meaning_vi,
    part_of_speech: row.part_of_speech,
    ipa: row.ipa,
    vietnamese_pronunciation: row.vietnamese_pronunciation,
    example: row.example,
    example_vi: row.example_vi,
    difficulty: row.difficulty,
    topics: JSON.parse(row.topics_json),
    entry_type: row.entry_type ?? 'word',
    explanation: row.explanation ?? '',
    generation_source: row.generation_source,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function rowToWorkplaceSentence(row) {
  return {
    id: row.id,
    text: row.text,
    normalized_text: row.normalized_text,
    language: row.language,
    meaning_vi: row.meaning_vi,
    topic: row.topic,
    source_article_id: row.source_article_id,
    source_title: row.source_title,
    generation_source: row.generation_source,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function rowToSubmittedWord(row) {
  return {
    id: row.id,
    user_id: row.user_id,
    device_id: row.device_id,
    submitted_term: row.submitted_term,
    normalized_term: row.normalized_term,
    language: row.language,
    status: row.status,
    failure_reason: row.failure_reason,
    resolution_type: row.resolution_type,
    resolved_word_id: row.resolved_word_id,
    created_at: row.created_at,
    updated_at: row.updated_at,
    resolved_at: row.resolved_at
  };
}

function hashUrl(url) {
  return crypto.createHash('sha256').update(String(url)).digest('hex');
}
