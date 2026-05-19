CREATE TABLE user_submitted_words (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  device_id TEXT NOT NULL,
  submitted_term TEXT NOT NULL,
  normalized_term TEXT NOT NULL,
  language TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  failure_reason TEXT,
  resolution_type TEXT,
  resolved_word_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  resolved_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (resolved_word_id) REFERENCES words(id)
);

CREATE TABLE user_submitted_word_jobs (
  id TEXT PRIMARY KEY,
  submission_id TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  queued_at TEXT NOT NULL,
  started_at TEXT,
  finished_at TEXT,
  error_message TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (submission_id) REFERENCES user_submitted_words(id)
);

CREATE INDEX idx_user_submitted_words_device_updated
  ON user_submitted_words(device_id, updated_at DESC);

CREATE INDEX idx_user_submitted_words_user_updated
  ON user_submitted_words(user_id, updated_at DESC)
  WHERE user_id IS NOT NULL;

CREATE UNIQUE INDEX idx_user_submitted_words_active_device_term
  ON user_submitted_words(device_id, language, normalized_term)
  WHERE user_id IS NULL AND status IN ('queued', 'processing');

CREATE UNIQUE INDEX idx_user_submitted_words_active_user_term
  ON user_submitted_words(user_id, language, normalized_term)
  WHERE user_id IS NOT NULL AND status IN ('queued', 'processing');

CREATE INDEX idx_user_submitted_words_resolved_word
  ON user_submitted_words(resolved_word_id)
  WHERE resolved_word_id IS NOT NULL;

CREATE INDEX idx_user_submitted_word_jobs_status_queued
  ON user_submitted_word_jobs(status, queued_at);
