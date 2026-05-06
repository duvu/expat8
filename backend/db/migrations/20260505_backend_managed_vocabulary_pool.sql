CREATE TABLE IF NOT EXISTS generation_runs (
  id TEXT PRIMARY KEY,
  target_language TEXT NOT NULL,
  mode TEXT NOT NULL,
  status TEXT NOT NULL,
  requested_count INTEGER NOT NULL,
  inserted_count INTEGER NOT NULL,
  error_message TEXT,
  run_date TEXT NOT NULL,
  started_at TEXT NOT NULL,
  finished_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scheduler_locks (
  target_language TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_cached_words (
  device_id TEXT NOT NULL,
  user_id TEXT,
  word_id TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (word_id) REFERENCES words(id)
);

ALTER TABLE user_word_states ADD COLUMN IF NOT EXISTS id TEXT;
ALTER TABLE user_word_states ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'en';
ALTER TABLE user_word_states ADD COLUMN IF NOT EXISTS last_rating TEXT;
ALTER TABLE user_word_states ADD COLUMN IF NOT EXISTS last_studied_at TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_word_states_device_word
ON user_word_states(device_id, word_id)
WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_word_states_user_word
ON user_word_states(user_id, word_id)
WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_generation_runs_language_date
ON generation_runs(target_language, mode, run_date);

CREATE INDEX IF NOT EXISTS idx_user_cached_words_device
ON user_cached_words(device_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_cached_words_user
ON user_cached_words(user_id, updated_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_cached_words_device_word
ON user_cached_words(device_id, word_id)
WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_cached_words_user_word
ON user_cached_words(user_id, word_id)
WHERE user_id IS NOT NULL;
