// In-memory practice-game rounds, weekly leaderboards and the games summary.

import { createId } from '../../ids.js';
import {
  InvalidGameRoundError,
  buildGamesSummary,
  gameWeekEnd,
  gameWeekStart,
  isGameSource,
  isPlausibleGameRound,
  leaderboardName,
  normalizeGameRound,
  rankLeaderboard
} from '../../game_rounds.js';

export class MemoryGameMethods {
  recordGameRounds({ deviceId, userId = null, rounds }) {
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
      if (this.gameRoundsByClientId.has(round.client_round_id)) {
        duplicates.push(round.client_round_id);
        continue;
      }
      this.gameRoundsByClientId.set(round.client_round_id, {
        id: createId('game_round'),
        ...round,
        device_id: deviceId,
        user_id: userId,
        leaderboard_eligible: isPlausibleGameRound(round),
        received_at: new Date().toISOString()
      });
      accepted.push(round.client_round_id);
    }
    return { accepted_round_ids: accepted, duplicates, rejected_rounds: rejected };
  }

  getGameLeaderboard({ game, mode, weekStart = null, userId = null, limit = 50 }) {
    const start = gameWeekStart(weekStart);
    const end = gameWeekEnd(start);
    const rows = [...this.gameRoundsByClientId.values()]
      .filter(
        (r) =>
          r.game === game &&
          r.mode === mode &&
          r.user_id &&
          r.leaderboard_eligible &&
          r.completed_at >= start &&
          r.completed_at < end
      )
      .map((r) => ({ ...r, display_name: leaderboardName(this.usersById.get(r.user_id)) }));
    return { game, mode, week_start: start, ...rankLeaderboard(rows, { limit, userId }) };
  }

  getGamesSummary({ days = 30, now = new Date() } = {}) {
    const since = new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString();
    const rounds = [...this.gameRoundsByClientId.values()].filter((r) => r.completed_at >= since);
    const reviewEvents = [...this.studyEventsByClientId.values()].filter(
      (e) => isGameSource(e.source) && e.occurred_at >= since
    );
    return buildGamesSummary({ rounds, gameReviewCount: reviewEvents.length, days });
  }
}
