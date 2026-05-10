import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
import {
  compareEventsForProjection,
  isPromptMissingRequiredFields,
  isSpeakingEvent,
  isUnknownSpeakingEvent,
  normalizeSpeakingEvent,
  normalizeSpeakingPromptInput,
  resolveEventKey,
  toApiSpeakingPrompt
} from './word_store.js';
import { normalizeSuggestionType } from './vocabulary_validator.js';
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

  async insertWord(input) {
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
      ipa: input.ipa,
      vietnamese_pronunciation: input.vietnamese_pronunciation,
      example: input.example,
      example_vi: input.example_vi,
      difficulty: normalizeDifficultyLevel(input.difficulty) ?? input.difficulty,
      topics_json: JSON.stringify(input.topics ?? []),
      generation_source: input.generation_source ?? 'seed',
      created_at: input.created_at ?? now,
      updated_at: input.updated_at ?? now
    };

    const inserted = await this.pool.query(
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
        generation_source,
        created_at,
        updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
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

    const existing = await this.pool.query(
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

  async countUsableWords({ targetLanguage = 'en' } = {}) {
    const result = await this.pool.query(
      `SELECT COUNT(*)::int AS count FROM words WHERE language = $1`,
      [targetLanguage]
    );
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
      const knownResult = distinctIds.length === 0
        ? { rows: [] }
        : await client.query(
            `SELECT id FROM words WHERE id = ANY($1)`,
            [distinctIds]
          );
      const knownIds = new Set(knownResult.rows.map((row) => row.id));
      const unknown = distinctIds.filter((wordId) => !knownIds.has(wordId));
      const stored = distinctIds.filter((wordId) => knownIds.has(wordId)).slice(0, 1000);
      const ownerWhere = userId ? 'user_id = $1' : 'device_id = $1 AND user_id IS NULL';
      await client.query(
        `DELETE FROM user_cached_words WHERE ${ownerWhere}`,
        [userId ?? deviceId]
      );
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
          VALUES ($1, $2, $3, $4, $5)`,
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
      const knownResult = distinctIds.length === 0
        ? { rows: [] }
        : await client.query(
            `SELECT id FROM words WHERE id = ANY($1)`,
            [distinctIds]
          );
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
      ? await this.pool.query(
          `SELECT word_id FROM user_cached_words WHERE user_id = $1`,
          [userId]
        )
      : await this.pool.query(
          `SELECT word_id FROM user_cached_words WHERE device_id = $1 AND user_id IS NULL`,
          [deviceId]
        );
    return new Set(result.rows.map((row) => row.word_id));
  }

  async wordStateFor({ deviceId, userId = null, wordId }) {
    const result = userId
      ? await this.pool.query(
          `SELECT * FROM user_word_states WHERE user_id = $1 AND word_id = $2 LIMIT 1`,
          [userId, wordId]
        )
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
        : this.pool.query(
            `SELECT * FROM user_word_states WHERE device_id = $1 AND user_id IS NULL AND language = $2`,
            [deviceId, targetLanguage]
          )
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
    const accepted = [];
    const duplicates = [];
    const rejected = [];
    let latestProficiency = await this.getProficiency({ deviceId, userId, language });

    const orderedEvents = [...events].sort(compareEventsForProjection);

    for (const event of orderedEvents) {
      const eventKey = resolveEventKey(event);
      if (isSpeakingEvent(event)) {
        if (!eventKey || !event.occurred_at) {
          rejected.push({
            client_event_id: event.client_event_id ?? null,
            event_id: event.event_id ?? null,
            reason: 'missing_required_field'
          });
          continue;
        }
        try {
          const result = await this.recordSpeakingEvent({ deviceId, userId, event, language });
          if (result.idempotent) {
            duplicates.push(eventKey);
          } else {
            accepted.push(eventKey);
          }
        } catch (error) {
          rejected.push({
            client_event_id: event.client_event_id ?? null,
            event_id: event.event_id ?? null,
            reason: error.message === 'forbidden_audio_field' ? 'forbidden_audio_field' : 'invalid_speaking_event'
          });
        }
        continue;
      }
      if (isUnknownSpeakingEvent(event)) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          event_id: event.event_id ?? null,
          reason: 'invalid_speaking_event_type'
        });
        continue;
      }
      if (!eventKey || !event.rating || !event.occurred_at) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          event_id: event.event_id ?? null,
          reason: 'missing_required_field'
        });
        continue;
      }
      try {
        const result = await this.recordStudyEvent({ deviceId, userId, event, language });
        latestProficiency = result.proficiency;
        if (result.idempotent) {
          duplicates.push(eventKey);
        } else {
          accepted.push(eventKey);
        }
      } catch (error) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          event_id: event.event_id ?? null,
          reason: error.name === 'InvalidStudyRatingError' ? 'invalid_rating' : 'invalid_event'
        });
        continue;
      }
    }

    this.logger.info?.('db_sync_study_events_completed', {
      device_id: deviceId,
      accepted_count: accepted.length,
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
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
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
      self_rating_counts: {
        clear: Number(row.clear_count ?? 0),
        hesitated: Number(row.hesitated_count ?? 0),
        could_not_say: Number(row.could_not_say_count ?? 0)
      },
      latest_activity_at: row.latest_activity_at ?? null
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
          [
            createId('user'),
            input.identifier,
            displayName,
            createPasswordHash(input.password),
            now,
            now
          ]
        );
      } catch (error) {
        if (error?.code === '23505') {
          throw new DuplicateUserError(input.identifier);
        }
        throw error;
      }
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
    if (!user || !verifyPassword(password, user.password_hash)) {
      throw new InvalidCredentialsError();
    }
    const sessionResult = await this.#createSessionForUser({
      client: this.pool,
      user,
      deviceId
    });
    return { user, ...sessionResult };
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
      const existing = await this.pool.query(
        `SELECT * FROM articles WHERE id = $1 LIMIT 1`,
        [articleId]
      );
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
    const existing = await this.pool.query(
      `SELECT * FROM speaking_prompts WHERE id = $1 LIMIT 1`,
      [promptId]
    );
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
      [
        createId('proficiency'),
        userId,
        deviceId,
        language,
        getDefaultProficiencyLevel({ language }),
        now,
        now
      ]
    );
    return inserted.rows[0];
  }

  async #applyProficiencyChange({ client, deviceId, userId = null, language, rating, currentLevel }) {
    const consecutiveCount = await this.countConsecutiveRatings({ deviceId, userId, rating, client });
    if (!isProgressionRating(rating) || consecutiveCount === 0 || consecutiveCount % 5 !== 0) {
      return null;
    }

    const previousLevel = normalizeDifficultyLevel(currentLevel, { language })
      ?? getDefaultProficiencyLevel({ language });
    const nextLevel = rating === 'too_easy'
      ? incrementLevel(previousLevel, { language })
      : decrementLevel(previousLevel, { language });

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
    const result = await this.pool.query(
      `SELECT * FROM articles WHERE id = $1 LIMIT 1`,
      [articleId]
    );
    return result.rows[0] ?? null;
  }

  async createAdminArticle({ adminUserId = null, title, sourceUrl = null, language, rawText, visibility = 'published' }) {
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
    const result = await this.pool.query(
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
    return result.rows[0] ?? null;
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

  async persistArticleVocabulary({ articleId, items = [] }) {
    return this.#withOptionalTransaction(async (client) => {
      const articleResult = await client.query(
        `SELECT * FROM articles WHERE id = $1 LIMIT 1 FOR UPDATE`,
        [articleId]
      );
      const article = articleResult.rows[0];
      if (!article) {
        throw new Error('article_not_found');
      }

      // Delete existing vocabulary for this article to prevent duplicates on reprocess
      const existingTermsResult = await client.query(
        `SELECT word_sense_id FROM article_terms WHERE article_id = $1`,
        [articleId]
      );
      const oldSenseIds = existingTermsResult.rows.map((r) => r.word_sense_id);
      await client.query(`DELETE FROM vocabulary_review_items WHERE article_id = $1`, [articleId]);
      await client.query(`DELETE FROM article_terms WHERE article_id = $1`, [articleId]);
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
        const termResult = await client.query(
          `INSERT INTO terms (id, language, display_term, normalized_term, lemma, created_at)
          VALUES ($1, $2, $3, $4, NULL, $5)
          ON CONFLICT (language, normalized_term) DO UPDATE SET display_term = EXCLUDED.display_term
          RETURNING *`,
          [createId('term'), item.language, item.term, normalized, now]
        );
        const term = termResult.rows[0];

        const sense = await client.query(
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
            now
          ]
        );

        await client.query(
          `INSERT INTO article_terms (
            id, article_id, term_id, word_sense_id, surface_text,
            sentence_context, start_offset, end_offset, frequency, extraction_confidence,
            classification, suggestion_type, created_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, NULL, NULL, $7, $8, $9, $10, $11)`,
          [
            createId('article_term'),
            articleId,
            term.id,
            sense.rows[0].id,
            item.term,
            item.example ?? null,
            Number(item.frequency ?? 1),
            Number(item.confidence ?? 0.5),
            item.classification ?? null,
            suggestionType,
            now
          ]
        );

        await client.query(
          `INSERT INTO vocabulary_review_items (
            id, word_sense_id, article_id, status,
            reviewer_user_id, review_note, reviewed_at, created_at, updated_at
          )
          VALUES ($1, $2, $3, $4, NULL, NULL, $5, $6, $6)`,
          [createId('review_item'), sense.rows[0].id, articleId, reviewStatus, reviewedAt, now]
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
      [
        createId('session'),
        user.id,
        hashSessionToken(sessionToken),
        deviceId,
        now
      ]
    );
    return {
      session: inserted.rows[0],
      sessionToken
    };
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
    generation_source: row.generation_source,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function statusForRating(rating) {
  if (rating === 'easy' || rating === 'too_easy') {
    return 'completed';
  }
  return rating === 'too_hard' ? 'learning' : 'review';
}

function nextReviewForRating(rating, occurredAt) {
  if (rating === 'easy' || rating === 'too_easy') {
    return null;
  }
  if (rating === 'too_hard') {
    return new Date(occurredAt.getTime() + 5 * 60 * 1000);
  }
  return new Date(occurredAt.getTime() + 24 * 60 * 60 * 1000);
}

function normalizeWeekStart(value) {
  if (typeof value === 'string' && value.trim()) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }
  const now = new Date();
  const day = now.getUTCDay();
  const diff = day === 0 ? 6 : day - 1;
  now.setUTCDate(now.getUTCDate() - diff);
  now.setUTCHours(0, 0, 0, 0);
  return now.toISOString();
}
