-- Migration: practice-game support.
-- 1. study_events.source tags reviews coming from games (e.g. game_word_blaster);
--    those events update word review state but not the proficiency ladder.
-- 2. game_rounds stores finished game rounds for analytics and the weekly
--    leaderboard (see contracts/api.md "Games").

ALTER TABLE study_events ADD COLUMN IF NOT EXISTS source TEXT;

CREATE INDEX IF NOT EXISTS idx_study_events_source_occurred
  ON study_events (source, occurred_at)
  WHERE source IS NOT NULL;

CREATE TABLE IF NOT EXISTS game_rounds (
  id TEXT PRIMARY KEY,
  client_round_id TEXT NOT NULL UNIQUE,
  device_id TEXT NOT NULL,
  user_id TEXT,
  game TEXT NOT NULL,
  mode TEXT NOT NULL,
  language TEXT NOT NULL,
  score INTEGER NOT NULL CHECK (score >= 0),
  correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
  answered_count INTEGER NOT NULL CHECK (answered_count >= 0),
  best_combo INTEGER NOT NULL CHECK (best_combo >= 0),
  wave INTEGER NOT NULL CHECK (wave >= 0),
  duration_ms INTEGER NOT NULL CHECK (duration_ms >= 0),
  leaderboard_eligible BOOLEAN NOT NULL DEFAULT TRUE,
  completed_at TEXT NOT NULL,
  received_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_game_rounds_leaderboard
  ON game_rounds (game, mode, completed_at)
  WHERE user_id IS NOT NULL AND leaderboard_eligible;

CREATE INDEX IF NOT EXISTS idx_game_rounds_device ON game_rounds (device_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_game_rounds_user ON game_rounds (user_id, completed_at DESC)
  WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_game_rounds_received ON game_rounds (received_at);
