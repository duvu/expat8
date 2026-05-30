import crypto from 'node:crypto';

import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
import { normalizeResolvedShadowingVideo } from './shadowing_videos.js';
import {
  isPromptMissingRequiredFields,
  normalizeSpeakingEvent,
  normalizeSpeakingPromptInput,
  resolveEventKey,
  routeStudyEvents,
  selectDistractors,
  submittedWordFailureReason,
  shuffleArray,
  shuffleChoices,
  toApiSpeakingPrompt
} from './word_store.js';
import { statusForRating, nextReviewForRating, normalizeWeekStart } from './store_utils.js';
import { normalizeSuggestionType } from './vocabulary_validator.js';
import { normalizeSentenceText } from './workplace_sentence_validator.js';
import {
  decrementLevel,
  getDefaultProficiencyLevel,
  getProficiencyProfile,
  incrementLevel,
  isProgressionRating,
  normalizeDifficultyLevel,
  requireStudyRating
} from './proficiency.js';
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

export class PostgresWordStore {
  constructor({ pool, logger = console, strictAttemptId = false }) {
    this.pool = pool;
    this.logger = logger;
    this.strictAttemptId = strictAttemptId;
  }

  async insertWord(input, { client = this.pool } = {}) {
    const normalizedTerm = normalizeTerm(input.term);
    const now = new Date().toISOString();
    const startedAt = Date.now();
    const row = {
      id: input.id ?? createId('word'),
      term: input.term,
      normalized_term: normalizedTerm,
      language: input.language,
      meaning_vi: input.meaning_vi,
      part_of_speech: input.part_of_speech ?? null,
      ipa: input.ipa ?? '',
      vietnamese_pronunciation: input.vietnamese_pronunciation ?? '',
      example: input.example ?? '',
      example_vi: input.example_vi ?? '',
      difficulty: normalizeDifficultyLevel(input.difficulty) ?? input.difficulty,
      topics_json: JSON.stringify(input.topics ?? []),
      entry_type: input.entry_type ?? 'word',
      blank_word: input.blank_word ?? null,
      explanation: input.explanation ?? '',
      generation_source: input.generation_source ?? 'seed',
      created_at: input.created_at ?? now,
      updated_at: input.updated_at ?? now
    };

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
      const distinctIds = [...new Set(wordIds.filter((wordId) => typeof wordId === 'string' && wordId.length > 0))];
      const knownResult =
        distinctIds.length === 0
          ? { rows: [] }
          : await client.query(`SELECT id FROM words WHERE id = ANY($1)`, [distinctIds]);
      const knownIds = new Set(knownResult.rows.map((row) => row.id));
      const unknown = distinctIds.filter((wordId) => !knownIds.has(wordId));
      const stored = distinctIds.filter((wordId) => knownIds.has(wordId)).slice(0, 1000);
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
      const distinctIds = [...new Set(wordIds.filter((wordId) => typeof wordId === 'string' && wordId.length > 0))];
      const knownResult =
        distinctIds.length === 0
          ? { rows: [] }
          : await client.query(`SELECT id FROM words WHERE id = ANY($1)`, [distinctIds]);
      const knownIds = new Set(knownResult.rows.map((row) => row.id));
      const unknown = distinctIds.filter((wordId) => !knownIds.has(wordId));
      const stored = distinctIds.filter((wordId) => knownIds.has(wordId)).slice(0, 1000);
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
      const submittedTerm = String(term ?? '').trim();
      const normalizedTerm = normalizeTerm(submittedTerm);
      const now = new Date().toISOString();
      const ownerWhere = userId
        ? 'user_id = $1 AND language = $2 AND normalized_term = $3'
        : 'device_id = $1 AND user_id IS NULL AND language = $2 AND normalized_term = $3';
      const ownerParams = userId ? [userId, language, normalizedTerm] : [deviceId, language, normalizedTerm];

      const activeResult = await client.query(
        `SELECT * FROM user_submitted_words
         WHERE ${ownerWhere} AND status IN ('queued', 'processing')
         ORDER BY created_at DESC
         LIMIT 1`,
        ownerParams
      );
      if (activeResult.rows[0]) {
        return {
          submission: await this.#hydrateSubmittedWord(client, rowToSubmittedWord(activeResult.rows[0])),
          created: false
        };
      }

      const readyResult = await client.query(
        `SELECT * FROM user_submitted_words
         WHERE ${ownerWhere} AND status = 'ready' AND resolved_word_id IS NOT NULL
         ORDER BY created_at DESC
         LIMIT 1`,
        ownerParams
      );
      if (readyResult.rows[0]) {
        return {
          submission: await this.#hydrateSubmittedWord(client, rowToSubmittedWord(readyResult.rows[0])),
          created: false
        };
      }

      const existingWordResult = await client.query(
        `SELECT * FROM words WHERE language = $1 AND normalized_term = $2 LIMIT 1`,
        [language, normalizedTerm]
      );
      if (existingWordResult.rows[0]) {
        const insertedReady = await client.query(
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
          VALUES ($1, $2, $3, $4, $5, $6, 'ready', NULL, 'existing_word', $7, $8, $8, $8)
          RETURNING *`,
          [
            createId('submitted_word'),
            userId,
            deviceId,
            submittedTerm,
            normalizedTerm,
            language,
            existingWordResult.rows[0].id,
            now
          ]
        );
        return {
          submission: await this.#hydrateSubmittedWord(client, rowToSubmittedWord(insertedReady.rows[0])),
          created: false
        };
      }

      if (generationService?.generateSubmittedWord) {
        try {
          const result = await generationService.generateSubmittedWord({
            targetLanguage: language,
            term: submittedTerm,
            persistWord: (candidate) => this.insertWord(candidate, { client })
          });
          const insertedReady = await client.query(
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
            VALUES ($1, $2, $3, $4, $5, $6, 'ready', NULL, $7, $8, $9, $9, $9)
            RETURNING *`,
            [
              createId('submitted_word'),
              userId,
              deviceId,
              submittedTerm,
              normalizedTerm,
              language,
              result.resolutionType ?? 'generated_word',
              result.word.id,
              now
            ]
          );
          return {
            submission: await this.#hydrateSubmittedWord(client, rowToSubmittedWord(insertedReady.rows[0])),
            created: true
          };
        } catch (error) {
          const insertedFailed = await client.query(
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
            VALUES ($1, $2, $3, $4, $5, $6, 'failed', $7, NULL, NULL, $8, $8, NULL)
            RETURNING *`,
            [
              createId('submitted_word'),
              userId,
              deviceId,
              submittedTerm,
              normalizedTerm,
              language,
              submittedWordFailureReason(error),
              now
            ]
          );
          return {
            submission: await this.#hydrateSubmittedWord(client, rowToSubmittedWord(insertedFailed.rows[0])),
            created: true
          };
        }
      }

      const insertedSubmission = await client.query(
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
        VALUES ($1, $2, $3, $4, $5, $6, 'queued', NULL, NULL, NULL, $7, $7, NULL)
        RETURNING *`,
        [createId('submitted_word'), userId, deviceId, submittedTerm, normalizedTerm, language, now]
      );
      const submission = rowToSubmittedWord(insertedSubmission.rows[0]);

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

      return {
        submission: await this.#hydrateSubmittedWord(client, submission),
        created: true
      };
    });
  }

  async listUserSubmittedWords({ deviceId, userId = null, limit = 50 }) {
    const result = userId
      ? await this.pool.query(
          `SELECT * FROM user_submitted_words
           WHERE user_id = $1
           ORDER BY updated_at DESC
           LIMIT $2`,
          [userId, Math.max(1, Math.min(limit, 100))]
        )
      : await this.pool.query(
          `SELECT * FROM user_submitted_words
           WHERE device_id = $1 AND user_id IS NULL
           ORDER BY updated_at DESC
           LIMIT $2`,
          [deviceId, Math.max(1, Math.min(limit, 100))]
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

  async learningCards({ deviceId, userId = null, targetLanguage = 'en', limit = 10, now = new Date().toISOString() }) {
    const cappedLimit = Math.max(1, Math.min(limit, 100));
    const targetReview = Math.floor(cappedLimit * 0.85);
    const [wordsResult, cachedIds, stateResult] = await Promise.all([
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
          ])
    ]);
    const words = wordsResult.rows.map(rowToWord);
    const wordById = new Map(words.map((w) => [w.id, w]));
    const stateWordIds = new Set(stateResult.rows.map((state) => state.word_id));

    // Due review items: next_review_at is set and <= now, ordered soonest first
    const dueStates = stateResult.rows
      .filter((state) => state.next_review_at && state.next_review_at <= now)
      .sort((a, b) => a.next_review_at.localeCompare(b.next_review_at));

    const reviewCards = dueStates
      .slice(0, targetReview)
      .map((state) => {
        const word = wordById.get(state.word_id);
        return word ? { word, cardType: 'review', selectionReason: 'srs_due' } : null;
      })
      .filter(Boolean);

    const newCount = cappedLimit - reviewCards.length;
    const newCandidates = words
      .filter((word) => !cachedIds.has(word.id))
      .filter((word) => !stateWordIds.has(word.id))
      .sort((left, right) => right.created_at.localeCompare(left.created_at));
    const newCards = newCandidates
      .slice(0, newCount)
      .map((word) => ({ word, cardType: 'new', selectionReason: 'new_available' }));

    const cards = [...reviewCards, ...newCards];
    await this.addCachedWordIds({
      deviceId,
      userId,
      wordIds: newCards.map((card) => card.word.id),
      observedAt: now
    });
    return {
      items: cards,
      target_mix: { new: cappedLimit - targetReview, review: targetReview },
      actual_mix: {
        new: newCards.length,
        review: reviewCards.length
      }
    };
  }

  async syncStudyEvents({ deviceId, events, language = 'en', userId = null }) {
    const startedAt = Date.now();
    const initialProficiency = await this.getProficiency({ deviceId, userId, language });

    const { accepted, duplicates, rejected, latestProficiency } = await routeStudyEvents({
      events,
      initialProficiency,
      recordSpeakingEvent: (event) => this.recordSpeakingEvent({ deviceId, userId, event, language }),
      recordStudyEvent: (event) => this.recordStudyEvent({ deviceId, userId, event, language })
    });

    this.logger.info?.('db_sync_study_events_completed', {
      device_id: deviceId,
      accepted_count: accepted.length,
      duplicate_count: duplicates.length,
      rejected_count: rejected.length,
      elapsed_ms: Date.now() - startedAt
    });
    return {
      accepted_event_ids: accepted,
      duplicates,
      rejected_events: rejected,
      proficiency: latestProficiency
    };
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
          received_at
        )
        SELECT $1, $2, $3, $4, $5,
          (SELECT id FROM words WHERE id = $6 LIMIT 1),
          $7, $8, $9, $10
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
          receivedAt
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

      const levelChange = await this.#applyProficiencyChange({
        client,
        deviceId,
        userId: eventUserId,
        language,
        rating: event.rating,
        currentLevel: proficiency.level
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

  async getProficiency({ deviceId, language = 'en', userId = null }) {
    return this.#buildProficiencyResponse({ deviceId, userId, language });
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

  async countConsecutiveRatings({ deviceId, rating, userId = null, client = this.pool }) {
    const events = await this.#recentEvents({ deviceId, userId, client });
    let count = 0;
    for (const event of events) {
      if (event.rating === rating) {
        count += 1;
      } else {
        break;
      }
    }
    return count;
  }

  async getLastRatingType({ deviceId, userId = null, client = this.pool }) {
    const events = await this.#recentEvents({ deviceId, userId, client });
    return events[0]?.rating ?? null;
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
          [createId('user'), input.identifier, displayName, createPasswordHash(input.password), now, now]
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
    if (!verifyPassword(password, user.password_hash)) {
      throw new InvalidCredentialsError();
    }
    return this.#withOptionalTransaction(async (client) => {
      // Claim device-only word states and cached words for the signing-in user
      await this.#claimDeviceWordStates({ client, userId: user.id, deviceId });
      await this.#claimDeviceCachedWords({ client, userId: user.id, deviceId });
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

    return {
      article_id: result.rows[0].article_id,
      items: result.rows.map((row) => ({
        term_id: row.term_id,
        display_term: row.display_term,
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
    const allowed = ['title', 'language', 'visibility', 'status'];
    const assignments = [];
    const values = [articleId];
    for (const field of allowed) {
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

  async listSpeakingPrompts({ status = null, missingRequired = false, limit = 100 } = {}) {
    const cappedLimit = Math.max(1, Math.min(limit, 200));
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
    const now = new Date().toISOString();
    const updated = normalizeSpeakingPromptInput({
      ...existing.rows[0],
      ...patch,
      reviewer_user_id: patch.status ? reviewerUserId : existing.rows[0].reviewer_user_id,
      reviewed_at: patch.status ? now : existing.rows[0].reviewed_at,
      updated_at: now
    });
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

  async #applyProficiencyChange({ client, deviceId, userId = null, language, rating, currentLevel }) {
    const consecutiveCount = await this.countConsecutiveRatings({ deviceId, userId, rating, client });
    if (!isProgressionRating(rating) || consecutiveCount === 0 || consecutiveCount % 5 !== 0) {
      return null;
    }

    const previousLevel =
      normalizeDifficultyLevel(currentLevel, { language }) ?? getDefaultProficiencyLevel({ language });
    const nextLevel =
      rating === 'too_easy' ? incrementLevel(previousLevel, { language }) : decrementLevel(previousLevel, { language });

    await client.query(
      `UPDATE user_proficiency
      SET level = $3, updated_at = $4
      WHERE ${userId ? 'user_id' : 'device_id'} = $1 AND language = $2`,
      [userId ?? deviceId, language, nextLevel, new Date().toISOString()]
    );

    return {
      levelChanged: nextLevel !== previousLevel,
      previousLevel,
      triggeredBy: `${consecutiveCount}x consecutive ${rating}`
    };
  }

  async #buildProficiencyResponse({
    deviceId,
    userId = null,
    language = 'en',
    client = this.pool,
    levelChanged = false,
    previousLevel = null,
    triggeredBy = null
  } = {}) {
    const proficiency = await this.getOrInitializeProficiency({ deviceId, userId, language, client });
    const currentRatingType = await this.getLastRatingType({ deviceId, userId, client });
    const consecutiveCount = currentRatingType
      ? await this.countConsecutiveRatings({ deviceId, userId, rating: currentRatingType, client })
      : 0;
    const profile = getProficiencyProfile({ language });

    return {
      scale: profile.scale,
      level: proficiency.level,
      level_index: profile.levels.indexOf(proficiency.level),
      level_changed: levelChanged,
      previous_level: previousLevel,
      triggered_by: triggeredBy,
      consecutive_count: levelChanged ? 0 : consecutiveCount,
      consecutive_rating_type: levelChanged ? null : currentRatingType,
      user_id: userId,
      language,
      last_updated: proficiency.updated_at
    };
  }

  async #recentEvents({ deviceId, userId = null, client = this.pool }) {
    const result = userId
      ? await client.query(
          `SELECT * FROM study_events
          WHERE user_id = $1
          ORDER BY occurred_at DESC, received_at DESC, id DESC
          LIMIT 10`,
          [userId]
        )
      : await client.query(
          `SELECT * FROM study_events
          WHERE device_id = $1
          ORDER BY occurred_at DESC, received_at DESC, id DESC
          LIMIT 10`,
          [deviceId]
        );
    return result.rows;
  }

  async createArticle({ userId, title, sourceUrl = null, language, rawText, visibility = 'private' }) {
    return this.#insertArticle({ ownerUserId: userId, title, sourceUrl, language, rawText, visibility });
  }

  async listArticles({ userId, limit = 50 }) {
    const result = await this.pool.query(
      `SELECT * FROM articles
      WHERE owner_user_id = $1 AND status <> 'deleted'
      ORDER BY created_at DESC
      LIMIT $2`,
      [userId, Math.max(1, Math.min(limit, 100))]
    );
    return result.rows;
  }

  async getArticleByIdForUser({ articleId, userId }) {
    const result = await this.pool.query(
      `SELECT * FROM articles
      WHERE id = $1 AND owner_user_id = $2 AND status <> 'deleted'
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
    return this.#insertArticle({ adminUserId, title, sourceUrl, language, rawText, visibility });
  }

  async listAdminArticles({ limit = 50, status = null }) {
    const result = await this.pool.query(
      `SELECT * FROM articles
      WHERE ($1::text IS NULL OR status = $1)
      ORDER BY created_at DESC
      LIMIT $2`,
      [status, Math.max(1, Math.min(limit, 100))]
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
      [status, Math.max(1, Math.min(limit, 200))]
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
      [language, afterVersion, Math.max(1, Math.min(limit, 200))]
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


  async #persistVocabularyItem({
    client,
    item,
    normalized,
    senseStatus,
    reviewStatus,
    reviewedAt,
    requiresReview,
    now,
    insertLinkRow,
    reviewArticleId,
    wordsExample,
    wordsTopicsJson,
    wordsGenSource,
  }) {
    const termResult = await client.query(
      `INSERT INTO terms (id, language, display_term, normalized_term, lemma, created_at)
      VALUES ($1, $2, $3, $4, NULL, $5)
      ON CONFLICT (language, normalized_term) DO UPDATE SET display_term = EXCLUDED.display_term
      RETURNING *`,
      [createId('term'), item.language, item.term, normalized, now]
    );
    const term = termResult.rows[0];

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
        item.part_of_speech ?? null,
        item.meaning_vi,
        item.short_definition ?? null,
        item.vietnamese_pronunciation ?? null,
        item.ipa ?? null,
        item.pinyin ?? null,
        item.level_scale ?? 'cefr',
        item.level ?? item.difficulty ?? 'A1',
        Number(item.quality_score ?? item.confidence ?? 0.5),
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
      await client.query(
        `INSERT INTO words (
          id, term, normalized_term, language, meaning_vi,
          part_of_speech, ipa, vietnamese_pronunciation,
          example, example_vi, difficulty, topics_json,
          generation_source, created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, '', $10, $11, $12, $13, $13)
        ON CONFLICT (language, normalized_term) DO NOTHING`,
        [
          createId('word'),
          item.term,
          normalized,
          item.language,
          item.meaning_vi ?? '',
          item.part_of_speech ?? null,
          item.ipa ?? '',
          item.vietnamese_pronunciation ?? '',
          wordsExample,
          item.level ?? item.difficulty ?? 'A1',
          wordsTopicsJson,
          wordsGenSource,
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
      const isAdmin = Boolean(article.created_by_admin_id);
      let persistedCount = 0;
      const seen = new Set();

      for (const item of items) {
        const normalized = normalizeTerm(item.term);
        const dedupeKey = `${item.language}:${normalized}`;
        if (seen.has(dedupeKey)) {
          continue;
        }
        seen.add(dedupeKey);
        // Stubs (fallback suggestions) are never auto-approved even for user articles
        const requiresReview = isAdmin || Boolean(item.isStub);
        const senseStatus = requiresReview ? 'pending_review' : 'approved';
        const reviewStatus = requiresReview ? 'pending' : 'approved';
        const reviewedAt = requiresReview ? null : now;
        const suggestionType = normalizeSuggestionType(item.suggestion_type, item.term);
        await this.#persistVocabularyItem({
          client, item, normalized, senseStatus, reviewStatus, reviewedAt,
          requiresReview, suggestionType, now,
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
          wordsExample: item.example ?? '',
          wordsTopicsJson: '[]',
          wordsGenSource: 'article_vocabulary',
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

  async #insertArticle({ ownerUserId = null, adminUserId = null, title, sourceUrl, language, rawText, visibility }) {
    const now = new Date().toISOString();
    const result = await this.pool.query(
      `INSERT INTO articles (
        id, owner_user_id, created_by_admin_id,
        title, source_url, language, raw_text, cleaned_text,
        visibility, status, processing_error, created_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, $8, 'pending_processing', NULL, $9, $9)
      RETURNING *`,
      [createId('article'), ownerUserId, adminUserId, title, sourceUrl, language, rawText, visibility, now]
    );
    const article = result.rows[0];
    await this.enqueueArticleProcessingJob({ articleId: article.id });
    return article;
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

  async #upsertWordState({ client, deviceId, userId = null, language, event }) {
    if (!event.word_id) {
      return;
    }
    const occurredAt = new Date(event.occurred_at);
    const nextReviewAt = nextReviewForRating(event.rating, occurredAt);
    const status = statusForRating(event.rating);
    const now = new Date().toISOString();
    const params = [
      createId('word_state'),
      userId,
      deviceId,
      event.word_id,
      language,
      status,
      event.rating,
      event.occurred_at,
      nextReviewAt?.toISOString() ?? null,
      now
    ];
    await client.query(
      userId
        ? `INSERT INTO user_word_states (
            id,
            user_id,
            device_id,
            word_id,
            language,
            status,
            last_rating,
            last_studied_at,
            next_review_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
          ON CONFLICT (user_id, word_id) WHERE user_id IS NOT NULL
          DO UPDATE SET
            device_id = EXCLUDED.device_id,
            language = EXCLUDED.language,
            status = EXCLUDED.status,
            last_rating = EXCLUDED.last_rating,
            last_studied_at = EXCLUDED.last_studied_at,
            next_review_at = EXCLUDED.next_review_at,
            review_count = user_word_states.review_count + 1,
            updated_at = EXCLUDED.updated_at`
        : `INSERT INTO user_word_states (
            id,
            user_id,
            device_id,
            word_id,
            language,
            status,
            last_rating,
            last_studied_at,
            next_review_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
          ON CONFLICT (device_id, word_id) WHERE user_id IS NULL
          DO UPDATE SET
            language = EXCLUDED.language,
            status = EXCLUDED.status,
            last_rating = EXCLUDED.last_rating,
            last_studied_at = EXCLUDED.last_studied_at,
            next_review_at = EXCLUDED.next_review_at,
            review_count = user_word_states.review_count + 1,
            updated_at = EXCLUDED.updated_at`,
      params
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
    if (typeof this.pool.connect !== 'function') {
      return work(this.pool);
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await work(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      this.logger.error?.('db_transaction_failed', { error });
      throw error;
    } finally {
      client.release();
    }
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

  // ─── Exam methods ──────────────────────────────────────────────────────────

  async examTopics({ userId, language = 'en' }) {
    const result = await this.pool.query(
      `SELECT DISTINCT w.topics_json
       FROM user_word_states uws
       JOIN words w ON w.id = uws.word_id
       WHERE uws.user_id = $1 AND uws.language = $2`,
      [userId, language]
    );
    const topicsSet = new Set();
    for (const row of result.rows) {
      let topics;
      try {
        topics = JSON.parse(row.topics_json ?? '[]');
      } catch {
        topics = [];
      }
      for (const t of topics) {
        const norm = String(t).trim().toLowerCase();
        if (norm) topicsSet.add(norm);
      }
    }
    return [...topicsSet].sort();
  }

  async startExamSession({ userId, language = 'en', now = new Date().toISOString(), sessionTtlMs = 7200000 }) {
    const expiresAt = new Date(new Date(now).getTime() + sessionTtlMs).toISOString();

    return this.#withOptionalTransaction(async (client) => {
      // Find studied words for the active language.
      const sourceResult = await client.query(
        `SELECT w.id, w.term, w.meaning_vi, w.difficulty, w.topics_json, w.language, w.example, w.entry_type
         FROM user_word_states uws
         JOIN words w ON w.id = uws.word_id
         WHERE uws.user_id = $1 AND uws.language = $2`,
        [userId, language]
      );
      const matchingWords = sourceResult.rows;

      if (matchingWords.length < 5) {
        return { error: 'INSUFFICIENT_WORDS', found: matchingWords.length };
      }

      const shuffledSource = shuffleArray([...matchingWords]).slice(0, 20);
      const sourceIds = new Set(shuffledSource.map((w) => w.id));

      // Distractor pool: same language, not a source word
      const distResult = await client.query(
        `SELECT id, term, meaning_vi, difficulty, example, entry_type FROM words WHERE language = $1`,
        [language]
      );
      const distractorPool = distResult.rows.filter((w) => !sourceIds.has(w.id));

      // Create session
      const sessionId = createId('exam_sess');
      await client.query(
        `INSERT INTO exam_sessions (id, user_id, topic, language, difficulty_level, created_at, expires_at, submitted_at)
         VALUES ($1, $2, $3, $4, NULL, $5, $6, NULL)`,
        [sessionId, userId, 'language', language, now, expiresAt]
      );

      const questions = [];
      for (let i = 0; i < shuffledSource.length; i++) {
        const src = shuffledSource[i];
        const distractors = selectDistractors({ source: src, pool: distractorPool, count: 3 });
        const correctMeaning = src.meaning_vi ?? src.term;
        const choicesRaw = [correctMeaning, ...distractors.map((d) => d.meaning_vi ?? d.term)];
        const { choices, correctIndex } = shuffleChoices(choicesRaw);

        // Assign question_type: 50/50 sentence_context if example is non-empty
        const hasExample = src.example && src.example.trim() !== '';
        const questionType = hasExample && Math.random() < 0.5 ? 'sentence_context' : 'meaning_choice';

        const question = {
          id: createId('exam_q'),
          session_id: sessionId,
          word_id: src.id,
          prompt_word: src.term,
          choices_json: JSON.stringify(choices),
          correct_index: correctIndex,
          ordinal: i,
          created_at: now,
          question_type: questionType,
          sentence: questionType === 'sentence_context' ? src.example : null,
          highlight: questionType === 'sentence_context' ? src.term : null
        };
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
        questions.push(question);
      }

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
    });
  }

  async submitExamSession({
    sessionId,
    userId,
    answers,
    now = new Date().toISOString(),
    passPct = 70,
    disclaimer: _disclaimer = ''
  }) {
    return this.#withOptionalTransaction(async (client) => {
      const sessResult = await client.query(`SELECT * FROM exam_sessions WHERE id = $1`, [sessionId]);
      if (sessResult.rows.length === 0) return { error: 'NOT_FOUND' };
      const session = sessResult.rows[0];
      if (session.submitted_at) return { error: 'ALREADY_SUBMITTED' };
      if (now > session.expires_at) return { error: 'SESSION_EXPIRED' };

      const qResult = await client.query(`SELECT * FROM exam_questions WHERE session_id = $1 ORDER BY ordinal`, [
        sessionId
      ]);
      const questions = qResult.rows;
      if (answers.length !== questions.length) {
        return { error: 'ANSWER_COUNT_MISMATCH', expected: questions.length, received: answers.length };
      }

      let correctCount = 0;
      for (let i = 0; i < questions.length; i++) {
        if (Number(answers[i]) === questions[i].correct_index) correctCount += 1;
      }
      const totalQuestions = questions.length;
      const scorePct = totalQuestions > 0 ? (correctCount / totalQuestions) * 100 : 0;
      const passed = scorePct >= passPct;

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
          totalQuestions,
          correctCount,
          scorePct,
          passed ? 1 : 0,
          now
        ]
      );

      let certificateId = null;
      if (passed) {
        certificateId = crypto.randomUUID();
        await client.query(
          `INSERT INTO exam_certificates (id, attempt_id, user_id, topic, language, difficulty_level, score_pct, issued_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [certificateId, attemptId, userId, session.topic, session.language, session.difficulty_level, scorePct, now]
        );
      }

      return {
        attempt_id: attemptId,
        session_id: sessionId,
        topic: session.topic,
        language: session.language,
        difficulty_level: session.difficulty_level,
        total_questions: totalQuestions,
        correct_count: correctCount,
        score_pct: scorePct,
        passed,
        certificate_id: certificateId,
        created_at: now
      };
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
    const CERTIFICATE_DISCLAIMER =
      'This is an internal Expat8 completion certificate. It does not represent an official CEFR or HSK examination result.';
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

  async createShadowingVideoEntry({ deviceId = null, userId = null, resolvedVideo, entryType = 'saved', visibility = 'private' }) {
    const normalized = normalizeResolvedShadowingVideo(resolvedVideo);
    return this.#withOptionalTransaction(async (client) => {
      const now = new Date().toISOString();
      let videoResult = await client.query(
        shadowingEntryVideoSql('sv.source_type = $1 AND sv.provider_video_id = $2 LIMIT 1'),
        [normalized.sourceType, normalized.providerVideoId]
      );

      if (!videoResult.rows[0]) {
        const insertedVideo = await client.query(
          `INSERT INTO shadowing_videos (
            id,
            source_type,
            provider_video_id,
            source_url,
            title,
            channel_title,
            thumbnail_url,
            duration_seconds,
            transcript_language,
            transcript_source,
            default_playback_rate,
            default_seek_back_ms,
            created_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $13)
          RETURNING *`,
          [
            createId('shadow_video'),
            normalized.sourceType,
            normalized.providerVideoId,
            normalized.sourceUrl,
            normalized.title,
            normalized.channelTitle,
            normalized.thumbnailUrl,
            normalized.durationSeconds,
            normalized.transcriptLanguage,
            normalized.transcriptSource,
            normalized.defaultPlaybackRate,
            normalized.defaultSeekBackMs,
            now
          ]
        );

        const videoId = insertedVideo.rows[0].id;
        for (const segment of normalized.segments) {
          await client.query(
            `INSERT INTO shadowing_video_segments (
              id,
              video_id,
              position,
              start_ms,
              end_ms,
              text,
              created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [createId('shadow_seg'), videoId, segment.position, segment.start_ms, segment.end_ms, segment.text, now]
          );
        }

        videoResult = await client.query(shadowingEntryVideoSql('sv.id = $1 LIMIT 1'), [videoId]);
      }

      const video = rowToShadowingVideo(videoResult.rows[0]);
      const ownerWhere = buildShadowingEntryOwnerWhere({ entryType, userId });
      const ownerParams = buildShadowingEntryOwnerParams({ videoId: video.id, deviceId, userId, entryType });
      const existingEntryResult = await client.query(
        `${shadowingEntrySelectSql(`sve.video_id = $1 AND sve.entry_type = $2 AND ${ownerWhere}`)} LIMIT 1`,
        ownerParams
      );
      if (existingEntryResult.rows[0]) {
        return {
          entry: rowToShadowingEntry(existingEntryResult.rows[0]),
          created: false
        };
      }

      const insertedEntry = await client.query(
        `INSERT INTO shadowing_video_entries (
          id,
          video_id,
          entry_type,
          visibility,
          owner_user_id,
          owner_device_id,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
        RETURNING id`,
        [
          createId('shadow_entry'),
          video.id,
          entryType,
          visibility ?? (entryType === 'curated' ? 'published' : 'private'),
          entryType === 'saved' ? userId : null,
          entryType === 'saved' && !userId ? deviceId : null,
          now
        ]
      );

      const hydratedEntryResult = await client.query(
        `${shadowingEntrySelectSql('sve.id = $1')} LIMIT 1`,
        [insertedEntry.rows[0].id]
      );
      return {
        entry: rowToShadowingEntry(hydratedEntryResult.rows[0]),
        created: true
      };
    });
  }

  async listShadowingVideoEntries({ deviceId, userId = null, limit = 50 }) {
    const boundedLimit = Math.max(1, Math.min(limit, 100));
    const whereSql = userId
      ? `(sve.entry_type = 'curated' AND sve.visibility = 'published') OR (sve.entry_type = 'saved' AND sve.owner_user_id = $1)`
      : `(sve.entry_type = 'curated' AND sve.visibility = 'published') OR (sve.entry_type = 'saved' AND sve.owner_user_id IS NULL AND sve.owner_device_id = $1)`;
    const params = [userId ?? deviceId, boundedLimit];
    const result = await this.pool.query(
      `${shadowingEntrySelectSql(whereSql)}
       ORDER BY CASE WHEN sve.entry_type = 'curated' THEN 0 ELSE 1 END, sve.updated_at DESC
       LIMIT $2`,
      params
    );
    return result.rows.map(rowToShadowingEntry);
  }

  async getShadowingVideoEntryDetail({ entryId }) {
    const entryResult = await this.pool.query(`${shadowingEntrySelectSql('sve.id = $1')} LIMIT 1`, [entryId]);
    if (!entryResult.rows[0]) {
      return null;
    }

    const segmentsResult = await this.pool.query(
      `SELECT * FROM shadowing_video_segments WHERE video_id = $1 ORDER BY position ASC`,
      [entryResult.rows[0].video_id]
    );
    return {
      ...rowToShadowingEntry(entryResult.rows[0]),
      segments: segmentsResult.rows.map(rowToShadowingSegment)
    };
  }

  // ─── Memorization Passages ───────────────────────────────────────────

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
      sql += ` AND (owner_user_id = $${idx++} OR visibility = 'published')`;
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
      const requiresReview = passage.owner_type !== 'user';
      const senseStatus = requiresReview ? 'pending_review' : 'approved';
      const reviewStatus = requiresReview ? 'pending' : 'approved';
      const reviewedAt = requiresReview ? null : now;
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
          client, item, normalized, senseStatus, reviewStatus, reviewedAt,
          requiresReview, suggestionType, now,
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
          wordsExample: item.example ?? segment.text,
          wordsTopicsJson: '["memorization"]',
          wordsGenSource: 'memorization_passage_vocabulary',
        });
        persistedCount += 1;
      }

      return { count: persistedCount };
    });
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
    return this.#withOptionalTransaction(async (client) => {
      const segmentResult = await client.query(
        `SELECT * FROM memorization_segments WHERE id = $1 LIMIT 1 FOR UPDATE`,
        [segmentId]
      );
      const segment = segmentResult.rows[0];
      if (!segment) return null;

      const index = Number(splitAt);
      if (!Number.isInteger(index) || index <= 0 || index >= segment.text.length) {
        return null;
      }
      const leftText = segment.text.slice(0, index).trim();
      const rightText = segment.text.slice(index).trim();
      if (!leftText || !rightText) {
        return null;
      }

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
    return this.#withOptionalTransaction(async (client) => {
      const result = await client.query(
        `SELECT * FROM memorization_segments WHERE id = ANY($1) FOR UPDATE`,
        [[segmentId, nextSegmentId]]
      );
      const segment = result.rows.find((row) => row.id === segmentId);
      const next = result.rows.find((row) => row.id === nextSegmentId);
      if (!segment || !next || segment.passage_id !== next.passage_id || next.position !== segment.position + 1) {
        return null;
      }

      const mergedText = `${segment.text.trim()} ${next.text.trim()}`.trim();
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
    const segments = await this.getSegmentsByPassage({ passageId });
    if (segments.length === 0) return { total: 0, mastered: 0, reviewing: 0, learning: 0, newCount: 0, percentage: 0 };
    const progress = await this.getSegmentProgress({ userId, passageId });
    const progressBySegment = new Map(progress.map((p) => [p.segment_id, p]));
    let mastered = 0, reviewing = 0, learning = 0, newCount = 0;
    for (const seg of segments) {
      const p = progressBySegment.get(seg.id);
      if (!p || p.status === 'new') newCount++;
      else if (p.status === 'mastered') mastered++;
      else if (p.status === 'review') reviewing++;
      else learning++;
    }
    const percentage = Math.round(((mastered + reviewing) / segments.length) * 100);
    return { total: segments.length, mastered, reviewing, learning, newCount, percentage };
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

function rowToShadowingVideo(row) {
  return {
    id: row.id,
    source_type: row.source_type,
    provider_video_id: row.provider_video_id,
    source_url: row.source_url,
    title: row.title,
    channel_title: row.channel_title,
    thumbnail_url: row.thumbnail_url,
    duration_seconds: row.duration_seconds,
    transcript_language: row.transcript_language,
    transcript_source: row.transcript_source,
    default_playback_rate: Number(row.default_playback_rate ?? 1),
    default_seek_back_ms: Number(row.default_seek_back_ms ?? 5000),
    segment_count: Number(row.segment_count ?? 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function rowToShadowingEntry(row) {
  return {
    id: row.id,
    video_id: row.video_id,
    entry_type: row.entry_type,
    visibility: row.visibility,
    owner_user_id: row.owner_user_id,
    owner_device_id: row.owner_device_id,
    source_type: row.source_type,
    provider_video_id: row.provider_video_id,
    source_url: row.source_url,
    title: row.title,
    channel_title: row.channel_title,
    thumbnail_url: row.thumbnail_url,
    duration_seconds: row.duration_seconds,
    transcript_language: row.transcript_language,
    transcript_source: row.transcript_source,
    default_playback_rate: Number(row.default_playback_rate ?? 1),
    default_seek_back_ms: Number(row.default_seek_back_ms ?? 5000),
    segment_count: Number(row.segment_count ?? 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function rowToShadowingSegment(row) {
  return {
    id: row.id,
    video_id: row.video_id,
    position: row.position,
    start_ms: row.start_ms,
    end_ms: row.end_ms,
    text: row.text,
    created_at: row.created_at
  };
}

function shadowingEntrySelectSql(whereSql) {
  return `SELECT
    sve.id,
    sve.video_id,
    sve.entry_type,
    sve.visibility,
    sve.owner_user_id,
    sve.owner_device_id,
    sve.created_at,
    sve.updated_at,
    sv.source_type,
    sv.provider_video_id,
    sv.source_url,
    sv.title,
    sv.channel_title,
    sv.thumbnail_url,
    sv.duration_seconds,
    sv.transcript_language,
    sv.transcript_source,
    sv.default_playback_rate,
    sv.default_seek_back_ms,
    COALESCE(segment_counts.segment_count, 0)::int AS segment_count
  FROM shadowing_video_entries sve
  JOIN shadowing_videos sv ON sv.id = sve.video_id
  LEFT JOIN (
    SELECT video_id, COUNT(*)::int AS segment_count
    FROM shadowing_video_segments
    GROUP BY video_id
  ) segment_counts ON segment_counts.video_id = sv.id
  WHERE ${whereSql}`;
}

function shadowingEntryVideoSql(whereSql) {
  return `SELECT
    sv.id,
    sv.source_type,
    sv.provider_video_id,
    sv.source_url,
    sv.title,
    sv.channel_title,
    sv.thumbnail_url,
    sv.duration_seconds,
    sv.transcript_language,
    sv.transcript_source,
    sv.default_playback_rate,
    sv.default_seek_back_ms,
    sv.created_at,
    sv.updated_at,
    COALESCE(segment_counts.segment_count, 0)::int AS segment_count
  FROM shadowing_videos sv
  LEFT JOIN (
    SELECT video_id, COUNT(*)::int AS segment_count
    FROM shadowing_video_segments
    GROUP BY video_id
  ) segment_counts ON segment_counts.video_id = sv.id
  WHERE ${whereSql}`;
}

function buildShadowingEntryOwnerWhere({ entryType, userId }) {
  if (entryType === 'curated') {
    return '1 = 1';
  }
  if (userId) {
    return 'sve.owner_user_id = $3';
  }
  return 'sve.owner_user_id IS NULL AND sve.owner_device_id = $3';
}

function buildShadowingEntryOwnerParams({ videoId, deviceId, userId, entryType }) {
  return [videoId, entryType, userId ?? deviceId];
}

function countWords(text) {
  return String(text ?? '').trim().split(/\s+/).filter(Boolean).length;
}
