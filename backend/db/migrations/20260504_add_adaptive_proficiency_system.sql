CREATE TABLE IF NOT EXISTS user_proficiency (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',
  level TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(device_id, language)
);

CREATE INDEX IF NOT EXISTS idx_user_proficiency_device_language
  ON user_proficiency(device_id, language);