CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  identifier TEXT NOT NULL UNIQUE,
  display_name TEXT,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  device_id TEXT,
  created_at TEXT NOT NULL,
  revoked_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

ALTER TABLE user_proficiency
  ADD COLUMN IF NOT EXISTS user_id TEXT;

CREATE INDEX IF NOT EXISTS idx_study_events_user
  ON study_events(user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_users_identifier
  ON users(identifier);

CREATE INDEX IF NOT EXISTS idx_user_sessions_token_hash
  ON user_sessions(token_hash);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user
  ON user_sessions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_proficiency_user_language
  ON user_proficiency(user_id, language);
