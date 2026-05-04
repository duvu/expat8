import { createId } from './ids.js';
import { normalizeTerm } from './normalize.js';

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
      difficulty: input.difficulty,
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

  async findNewWords({ targetLanguage = 'en', limit = 1, excludeWordIds = [] }) {
    const filters = ['language = $1'];
    const params = [targetLanguage];

    if (excludeWordIds.length > 0) {
      params.push(excludeWordIds);
      filters.push(`id <> ALL($${params.length})`);
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

  async syncStudyEvents({ deviceId, events }) {
    const accepted = [];
    const rejected = [];
    const receivedAt = new Date().toISOString();

    for (const event of events) {
      if (!event.client_event_id || !event.rating || !event.occurred_at) {
        rejected.push({
          client_event_id: event.client_event_id ?? null,
          reason: 'missing_required_field'
        });
        continue;
      }

      await this.pool.query(
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
        ON CONFLICT (client_event_id) DO NOTHING`,
        [
          createId('study_event'),
          event.client_event_id,
          deviceId,
          event.user_id ?? null,
          event.server_word_id ?? null,
          event.local_word_id ?? null,
          event.rating,
          event.occurred_at,
          receivedAt
        ]
      );
      accepted.push(event.client_event_id);
    }

    return {
      accepted_event_ids: accepted,
      rejected_events: rejected
    };
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
