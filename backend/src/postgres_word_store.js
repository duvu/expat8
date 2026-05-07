import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
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
  constructor({ pool, logger = console }) {
    this.pool = pool;
    this.logger = logger;
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
    const stateWordIds = new Set(stateResult.rows.map((state) => state.word_id));
    const newCandidates = words
      .filter((word) => !cachedIds.has(word.id))
      .filter((word) => !stateWordIds.has(word.id))
      .sort((left, right) => right.created_at.localeCompare(left.created_at));
    const cards = newCandidates
      .slice(0, cappedLimit)
      .map((word) => ({ word, cardType: 'new', selectionReason: 'new_available' }));
    await this.addCachedWordIds({
      deviceId,
      userId,
      wordIds: cards.map((card) => card.word.id),
      observedAt: now
    });
    return {
      items: cards,
      target_mix: { new: cappedLimit, review: 0 },
      actual_mix: {
        new: cards.length,
        review: 0
      }
    };
  }

  async syncStudyEvents({ deviceId, events, language = 'en', userId = null }) {
    const startedAt = Date.now();
    const accepted = [];
    const rejected = [];
    let latestProficiency = await this.getProficiency({ deviceId, userId, language });

    for (const event of events) {
      if (!event.client_event_id || !event.rating || !event.occurred_at) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: 'missing_required_field'
        });
        continue;
      }
      try {
        const result = await this.recordStudyEvent({ deviceId, userId, event, language });
        latestProficiency = result.proficiency;
      } catch (error) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: error.name === 'InvalidStudyRatingError' ? 'invalid_rating' : 'invalid_event'
        });
        continue;
      }
      accepted.push(event.client_event_id);
    }

    this.logger.info?.('db_sync_study_events_completed', {
      device_id: deviceId,
      accepted_count: accepted.length,
      rejected_count: rejected.length,
      elapsed_ms: Date.now() - startedAt
    });
    return {
      accepted_event_ids: accepted,
      rejected_events: rejected,
      proficiency: latestProficiency
    };
  }

  async recordStudyEvent({ deviceId, event, language = 'en', userId = null }) {
    requireStudyRating(event.rating);

    return this.#withOptionalTransaction(async (client) => {
      const startedAt = Date.now();
      const receivedAt = new Date().toISOString();
      const inserted = await client.query(
        `INSERT INTO study_events (
          id,
          client_event_id,
          device_id,
          user_id,
          word_id,
          local_word_id,
          rating,
          occurred_at,
          received_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (client_event_id) DO NOTHING
        RETURNING *`,
        [
          createId('study_event'),
          event.client_event_id,
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
          client_event_id: event.client_event_id,
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
        client_event_id: event.client_event_id,
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
          ORDER BY occurred_at DESC, received_at DESC
          LIMIT 10`,
          [userId]
        )
      : await client.query(
          `SELECT * FROM study_events
          WHERE device_id = $1
          ORDER BY occurred_at DESC, received_at DESC
          LIMIT 10`,
          [deviceId]
        );
    return result.rows;
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
