// PostgreSQL practice-game rounds, weekly leaderboards and the games summary.

import { createId } from '../../ids.js';
import {
  InvalidGameRoundError,
  buildGamesSummary,
  gameWeekEnd,
  gameWeekStart,
  isPlausibleGameRound,
  leaderboardName,
  normalizeGameRound,
  rankLeaderboard
} from '../../game_rounds.js';

export class PostgresGameMethods {
  async recordGameRounds({ deviceId, userId = null, rounds }) {
    const accepted = [];
    const duplicates = [];
    const rejected = [];
    for (const raw of rounds) {
      let round;
      try {
        round = normalizeGameRound(raw);
      } catch (error) {
        if (!(error instanceof InvalidGameRoundError)) throw error;
        rejected.push({ client_round_id: raw?.client_round_id ?? null, reason: error.reason });
        continue;
      }
      const inserted = await this.pool.query(
        `INSERT INTO game_rounds (
          id, client_round_id, device_id, user_id, game, mode, language, score,
          correct_count, answered_count, best_combo, wave, duration_ms,
          leaderboard_eligible, completed_at, received_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
        ON CONFLICT (client_round_id) DO NOTHING
        RETURNING id`,
        [
          createId('game_round'),
          round.client_round_id,
          deviceId,
          userId,
          round.game,
          round.mode,
          round.language,
          round.score,
          round.correct_count,
          round.answered_count,
          round.best_combo,
          round.wave,
          round.duration_ms,
          isPlausibleGameRound(round),
          round.completed_at,
          new Date().toISOString()
        ]
      );
      (inserted.rows[0] ? accepted : duplicates).push(round.client_round_id);
    }
    return { accepted_round_ids: accepted, duplicates, rejected_rounds: rejected };
  }

  async getGameLeaderboard({ game, mode, weekStart = null, userId = null, limit = 50 }) {
    const start = gameWeekStart(weekStart);
    const end = gameWeekEnd(start);
    const result = await this.pool.query(
      `SELECT r.user_id, r.score, r.correct_count, r.answered_count, r.best_combo, r.completed_at,
              u.display_name, u.identifier
       FROM game_rounds r
       JOIN users u ON u.id = r.user_id
       WHERE r.game = $1 AND r.mode = $2 AND r.user_id IS NOT NULL AND r.leaderboard_eligible
         AND r.completed_at >= $3 AND r.completed_at < $4`,
      [game, mode, start, end]
    );
    const rows = result.rows.map((row) => ({ ...row, display_name: leaderboardName(row) }));
    return { game, mode, week_start: start, ...rankLeaderboard(rows, { limit, userId }) };
  }

  async getGamesSummary({ days = 30, now = new Date() } = {}) {
    const since = new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString();
    const rounds = await this.pool.query('SELECT * FROM game_rounds WHERE completed_at >= $1', [since]);
    const reviews = await this.pool.query(
      `SELECT count(*)::int AS n FROM study_events
       WHERE source LIKE 'game\\_%' AND occurred_at >= $1`,
      [since]
    );
    return buildGamesSummary({ rounds: rounds.rows, gameReviewCount: reviews.rows[0].n, days });
  }
}
