-- Migration: speaking-foundation
-- Adds reviewed speaking prompts and metadata-only speaking event tracking.
-- Requires content-ingestion-v2-foundation tables to exist first.

CREATE TABLE IF NOT EXISTS speaking_prompts (
  id TEXT PRIMARY KEY,
  word_sense_id TEXT NOT NULL,
  article_term_id TEXT,
  target_text TEXT NOT NULL,
  vi_hint TEXT NOT NULL,
  target_phrase TEXT,
  pronunciation_tip_vi TEXT,
  common_mistake_vi TEXT,
  difficulty TEXT,
  topic TEXT,
  status TEXT NOT NULL DEFAULT 'pending_review',
  reviewer_user_id TEXT,
  reviewed_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (word_sense_id) REFERENCES word_senses(id),
  FOREIGN KEY (article_term_id) REFERENCES article_terms(id),
  FOREIGN KEY (reviewer_user_id) REFERENCES users(id),
  CHECK (status IN ('pending_review', 'approved', 'rejected'))
);

CREATE TABLE IF NOT EXISTS speaking_events (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  client_event_id TEXT,
  device_id TEXT NOT NULL,
  user_id TEXT,
  event_type TEXT NOT NULL,
  attempt_id TEXT NOT NULL,
  prompt_id TEXT,
  word_sense_id TEXT,
  server_word_id TEXT,
  duration_ms INTEGER,
  retry_count INTEGER NOT NULL DEFAULT 0,
  self_rating TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  occurred_at TEXT NOT NULL,
  received_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (prompt_id) REFERENCES speaking_prompts(id),
  FOREIGN KEY (word_sense_id) REFERENCES word_senses(id),
  FOREIGN KEY (server_word_id) REFERENCES words(id),
  UNIQUE(event_id),
  CHECK (event_type IN (
    'speaking_prompt_viewed',
    'speaking_sample_played',
    'speaking_recorded',
    'speaking_retried',
    'speaking_self_rated_clear',
    'speaking_self_rated_hesitated',
    'speaking_self_rated_could_not_say'
  )),
  CHECK (self_rating IS NULL OR self_rating IN ('clear', 'hesitated', 'could_not_say')),
  CHECK (duration_ms IS NULL OR duration_ms >= 0),
  CHECK (retry_count >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_speaking_events_client_event_id
  ON speaking_events (client_event_id)
  WHERE client_event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_speaking_prompts_word_sense_status
  ON speaking_prompts (word_sense_id, status);

CREATE INDEX IF NOT EXISTS idx_speaking_prompts_article_term
  ON speaking_prompts (article_term_id)
  WHERE article_term_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_speaking_prompts_status_updated
  ON speaking_prompts (status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_speaking_events_device_occurred
  ON speaking_events (device_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_speaking_events_user_occurred
  ON speaking_events (user_id, occurred_at DESC)
  WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_speaking_events_prompt_occurred
  ON speaking_events (prompt_id, occurred_at DESC)
  WHERE prompt_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_speaking_events_attempt
  ON speaking_events (attempt_id, occurred_at DESC);
