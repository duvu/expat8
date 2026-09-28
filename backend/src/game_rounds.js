/**
 * Game round validation shared by the in-memory and PostgreSQL stores.
 * See contracts/api.md "Games" and docs/games/20260928-word-blaster-game-design.md.
 */

export const GAME_MODES = {
  word_blaster: ['classic', 'reverse', 'listening', 'fillGap', 'timeAttack']
};

// Scoring caps from the Word Blaster rules: 100 points x combo multiplier (<= 4)
// x speed bonus (<= 1.5) x bonus wave (<= 1.5) per correct answer, plus 1000
// per defeated boss (at most one boss every 5 waves).
const MAX_POINTS_PER_CORRECT = 100 * 4 * 1.5 * 1.5;
const BOSS_BONUS = 1000;
const BOSS_EVERY = 5;
const MIN_MS_PER_ANSWER = 400;
const MAX_ROUND_MS = 2 * 60 * 60 * 1000;

export class InvalidGameRoundError extends Error {
  constructor(reason) {
    super(reason);
    this.name = 'InvalidGameRoundError';
    this.reason = reason;
  }
}

function nonNegativeInt(value) {
  return Number.isInteger(value) && value >= 0;
}

/**
 * Validates shape and returns a normalized round. Throws InvalidGameRoundError
 * for malformed input (the client should drop it).
 */
export function normalizeGameRound(round) {
  if (!round || typeof round !== 'object') throw new InvalidGameRoundError('invalid_round');
  const clientRoundId = typeof round.client_round_id === 'string' ? round.client_round_id.trim() : '';
  if (!clientRoundId || clientRoundId.length > 100) throw new InvalidGameRoundError('missing_client_round_id');
  const modes = GAME_MODES[round.game];
  if (!modes) throw new InvalidGameRoundError('unknown_game');
  if (!modes.includes(round.mode)) throw new InvalidGameRoundError('unknown_mode');
  for (const field of ['score', 'correct_count', 'answered_count', 'best_combo', 'wave', 'duration_ms']) {
    if (!nonNegativeInt(round[field])) throw new InvalidGameRoundError(`invalid_${field}`);
  }
  const completedAt = new Date(round.completed_at ?? '');
  if (Number.isNaN(completedAt.getTime())) throw new InvalidGameRoundError('invalid_completed_at');
  const language = typeof round.language === 'string' && round.language.trim() ? round.language.trim() : 'en';
  return {
    client_round_id: clientRoundId,
    game: round.game,
    mode: round.mode,
    language: language.slice(0, 16),
    score: round.score,
    correct_count: round.correct_count,
    answered_count: round.answered_count,
    best_combo: round.best_combo,
    wave: round.wave,
    duration_ms: round.duration_ms,
    completed_at: completedAt.toISOString()
  };
}

/**
 * Whether a normalized round is plausible enough for the public leaderboard.
 * Implausible rounds are still stored for analytics.
 */
export function isPlausibleGameRound(round) {
  if (round.correct_count > round.answered_count) return false;
  if (round.best_combo > round.correct_count) return false;
  if (round.duration_ms > MAX_ROUND_MS) return false;
  if (round.answered_count > 0 && round.duration_ms / round.answered_count < MIN_MS_PER_ANSWER) return false;
  const bosses = Math.floor(round.wave / BOSS_EVERY);
  const maxScore = round.correct_count * MAX_POINTS_PER_CORRECT + bosses * BOSS_BONUS;
  return round.score <= maxScore;
}

/** Monday 00:00 UTC of the week containing `value` (or now). */
export function gameWeekStart(value) {
  const parsed = typeof value === 'string' && value.trim() ? new Date(value) : new Date();
  const date = Number.isNaN(parsed.getTime()) ? new Date() : parsed;
  const day = date.getUTCDay();
  const diff = day === 0 ? 6 : day - 1;
  const start = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() - diff));
  return start.toISOString();
}

export function gameWeekEnd(weekStart) {
  return new Date(new Date(weekStart).getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();
}

/** Public name for leaderboards: display name, else the identifier's local part, masked. */
export function leaderboardName(user) {
  const display = user?.display_name?.trim();
  if (display) return display.slice(0, 24);
  const local = String(user?.identifier ?? 'player').split('@')[0];
  if (local.length <= 2) return `${local}***`;
  return `${local.slice(0, 2)}***`;
}

/** Keeps the best round per user and ranks them. */
export function rankLeaderboard(rows, { limit = 50, userId = null } = {}) {
  const bestByUser = new Map();
  for (const row of rows) {
    const current = bestByUser.get(row.user_id);
    if (
      !current ||
      row.score > current.score ||
      (row.score === current.score && row.completed_at < current.completed_at)
    ) {
      bestByUser.set(row.user_id, row);
    }
  }
  const ranked = [...bestByUser.values()].sort(
    (a, b) => b.score - a.score || String(a.completed_at).localeCompare(String(b.completed_at))
  );
  const toEntry = (row, index) => ({
    rank: index + 1,
    display_name: row.display_name,
    score: row.score,
    accuracy: row.answered_count === 0 ? 0 : Math.round((row.correct_count / row.answered_count) * 100) / 100,
    best_combo: row.best_combo,
    is_me: userId !== null && row.user_id === userId
  });
  const entries = ranked.slice(0, limit).map(toEntry);
  const myIndex = userId ? ranked.findIndex((row) => row.user_id === userId) : -1;
  return { entries, me: myIndex >= 0 ? toEntry(ranked[myIndex], myIndex) : null };
}

const SOURCE_PATTERN = /^[a-z0-9_]{1,64}$/;

/** Accepts a study-event `source` tag like `game_word_blaster`; anything else becomes null. */
export function normalizeEventSource(value) {
  return typeof value === 'string' && SOURCE_PATTERN.test(value) ? value : null;
}

/** Study events from practice games update word review state only. */
export function isGameSource(source) {
  return typeof source === 'string' && source.startsWith('game_');
}

/** Admin analytics over finished rounds (both stores share this shape). */
export function buildGamesSummary({ rounds, gameReviewCount, days }) {
  const perDay = new Map();
  const byMode = {};
  const buckets = { under_50: 0, from_50_to_70: 0, from_70_to_85: 0, from_85: 0 };
  let correct = 0;
  let answered = 0;
  for (const r of rounds) {
    const day = String(r.completed_at).slice(0, 10);
    const entry = perDay.get(day) ?? { day, rounds: 0, players: new Set() };
    entry.rounds += 1;
    entry.players.add(r.user_id ?? `device:${r.device_id}`);
    perDay.set(day, entry);
    const modeKey = `${r.game}:${r.mode}`;
    byMode[modeKey] = (byMode[modeKey] ?? 0) + 1;
    correct += r.correct_count;
    answered += r.answered_count;
    const accuracy = r.answered_count === 0 ? 0 : r.correct_count / r.answered_count;
    if (accuracy < 0.5) buckets.under_50 += 1;
    else if (accuracy < 0.7) buckets.from_50_to_70 += 1;
    else if (accuracy < 0.85) buckets.from_70_to_85 += 1;
    else buckets.from_85 += 1;
  }
  const players = new Set(rounds.map((r) => r.user_id ?? `device:${r.device_id}`));
  return {
    days,
    total_rounds: rounds.length,
    players: players.size,
    mean_accuracy: answered === 0 ? 0 : Math.round((correct / answered) * 1000) / 1000,
    words_reviewed_via_games: gameReviewCount,
    rounds_by_mode: byMode,
    accuracy_buckets: buckets,
    rounds_per_day: [...perDay.values()]
      .sort((a, b) => a.day.localeCompare(b.day))
      .map((e) => ({ day: e.day, rounds: e.rounds, players: e.players.size }))
  };
}
