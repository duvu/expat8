import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';
import {
  DEFAULT_PROFICIENCY_LEVEL,
  decrementLevel,
  getFallbackDifficultyLevels,
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
  constructor({ pool }) {
    this.pool = pool;
  }

  async insertWord(input) {
    const normalizedTerm = normalizeTerm(input.term);
    const now = new Date().toISOString();
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
      return { word: rowToWord(inserted.rows[0]), inserted: true };
    }

    const existing = await this.pool.query(
      `SELECT * FROM words
      WHERE language = $1 AND normalized_term = $2
      LIMIT 1`,
      [row.language, row.normalized_term]
    );
    return { word: rowToWord(existing.rows[0]), inserted: false };
  }

  async findNewWords({ targetLanguage = 'en', limit = 1, excludeWordIds = [], proficiencyLevel, deviceId, userId }) {
    const resolvedLevel = proficiencyLevel
      ? normalizeDifficultyLevel(proficiencyLevel)
      : deviceId || userId
        ? (await this.getProficiency({ deviceId, userId, language: targetLanguage })).level
        : null;

    if (!resolvedLevel) {
      return this.#findWordsForLevel({
        targetLanguage,
        limit,
        excludeWordIds,
        deviceId,
        userId
      });
    }

    for (const level of getFallbackDifficultyLevels(resolvedLevel)) {
      const words = await this.#findWordsForLevel({
        targetLanguage,
        limit,
        excludeWordIds,
        deviceId,
        userId,
        proficiencyLevel: level
      });
      if (words.length > 0) {
        return words;
      }
    }

    return [];
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

  async syncStudyEvents({ deviceId, events, language = 'en', userId = null }) {
    const accepted = [];
    const rejected = [];
    let latestResult = await this.getProficiency({ deviceId, userId, language });

    for (const event of events) {
      if (!event.client_event_id || !event.rating || !event.occurred_at) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: 'missing_required_field'
        });
        continue;
      }
      try {
        latestResult = await this.recordStudyEvent({ deviceId, userId, event, language });
      } catch (error) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: error.name === 'InvalidStudyRatingError' ? 'invalid_rating' : 'invalid_event'
        });
        continue;
      }
      accepted.push(event.client_event_id);
    }

    return {
      accepted_event_ids: accepted,
      rejected_events: rejected,
      proficiency: latestResult.proficiency
    };
  }

  async recordStudyEvent({ deviceId, event, language = 'en', userId = null }) {
    requireStudyRating(event.rating);

    return this.#withOptionalTransaction(async (client) => {
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
        return {
          eventId: null,
          idempotent: true,
          proficiency: await this.#buildProficiencyResponse({ client, deviceId, userId, language })
        };
      }

      const levelChange = await this.#applyProficiencyChange({
        client,
        deviceId,
        userId: eventUserId,
        language,
        rating: event.rating,
        currentLevel: proficiency.level
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
      const inserted = await client.query(
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
    const profileDeviceId = userId ? `user:${userId}` : deviceId;
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
      ON CONFLICT (device_id, language) DO UPDATE SET updated_at = user_proficiency.updated_at
      RETURNING *`,
      [
        createId('proficiency'),
        userId,
        profileDeviceId,
        language,
        DEFAULT_PROFICIENCY_LEVEL,
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

    const previousLevel = normalizeDifficultyLevel(currentLevel) ?? DEFAULT_PROFICIENCY_LEVEL;
    const nextLevel = rating === 'too_easy'
      ? incrementLevel(previousLevel)
      : decrementLevel(previousLevel);

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

    return {
      level: proficiency.level,
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

  async #findWordsForLevel({ targetLanguage, limit, excludeWordIds, proficiencyLevel, deviceId, userId }) {
    const filters = ['language = $1'];
    const params = [targetLanguage];

    if (proficiencyLevel) {
      params.push(proficiencyLevel);
      filters.push(`difficulty = $${params.length}`);
    }

    if (excludeWordIds.length > 0) {
      params.push(excludeWordIds);
      filters.push(`id <> ALL($${params.length})`);
    }

    if (userId || deviceId) {
      params.push(userId ?? deviceId);
      filters.push(
        `id NOT IN (
          SELECT word_id FROM study_events
          WHERE ${userId ? 'user_id' : 'device_id'} = $${params.length}
          AND word_id IS NOT NULL
        )`
      );
    }

    params.push(limit);
    const result = await this.pool.query(
      `SELECT * FROM words
      WHERE ${filters.join('\n      AND ')}
      ORDER BY created_at DESC
      LIMIT $${params.length}`,
      params
    );
    return result.rows.map(rowToWord);
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
