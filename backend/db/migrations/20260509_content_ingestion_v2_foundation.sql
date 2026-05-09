-- Migration: content-ingestion-v2-foundation
-- Adds ingestion/admin/content-pack tables and deterministic study-event ordering indexes.

CREATE TABLE IF NOT EXISTS articles (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT,
  created_by_admin_id TEXT,
  title TEXT NOT NULL,
  source_url TEXT,
  language TEXT NOT NULL,
  raw_text TEXT NOT NULL,
  cleaned_text TEXT,
  visibility TEXT NOT NULL DEFAULT 'private',
  status TEXT NOT NULL DEFAULT 'pending_processing',
  processing_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS article_processing_jobs (
  id TEXT PRIMARY KEY,
  article_id TEXT NOT NULL,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  queued_at TEXT NOT NULL,
  started_at TEXT,
  finished_at TEXT,
  error_message TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (article_id) REFERENCES articles(id)
);

CREATE TABLE IF NOT EXISTS terms (
  id TEXT PRIMARY KEY,
  language TEXT NOT NULL,
  display_term TEXT NOT NULL,
  normalized_term TEXT NOT NULL,
  lemma TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(language, normalized_term)
);

CREATE TABLE IF NOT EXISTS word_senses (
  id TEXT PRIMARY KEY,
  term_id TEXT NOT NULL,
  part_of_speech TEXT,
  meaning_vi TEXT NOT NULL,
  short_definition TEXT,
  pronunciation TEXT,
  ipa TEXT,
  pinyin TEXT,
  level_scale TEXT,
  level TEXT,
  quality_score REAL,
  status TEXT NOT NULL DEFAULT 'pending_review',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (term_id) REFERENCES terms(id)
);

CREATE TABLE IF NOT EXISTS article_terms (
  id TEXT PRIMARY KEY,
  article_id TEXT NOT NULL,
  term_id TEXT NOT NULL,
  word_sense_id TEXT,
  surface_text TEXT NOT NULL,
  sentence_context TEXT,
  start_offset INTEGER,
  end_offset INTEGER,
  frequency INTEGER NOT NULL DEFAULT 1,
  extraction_confidence REAL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (article_id) REFERENCES articles(id),
  FOREIGN KEY (term_id) REFERENCES terms(id),
  FOREIGN KEY (word_sense_id) REFERENCES word_senses(id)
);

CREATE TABLE IF NOT EXISTS vocabulary_review_items (
  id TEXT PRIMARY KEY,
  word_sense_id TEXT NOT NULL,
  article_id TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  reviewer_user_id TEXT,
  review_note TEXT,
  reviewed_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (word_sense_id) REFERENCES word_senses(id),
  FOREIGN KEY (article_id) REFERENCES articles(id),
  FOREIGN KEY (reviewer_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS content_packs (
  id TEXT PRIMARY KEY,
  language TEXT NOT NULL,
  version INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'published',
  created_at TEXT NOT NULL,
  published_at TEXT,
  UNIQUE(language, version)
);

CREATE TABLE IF NOT EXISTS content_pack_items (
  id TEXT PRIMARY KEY,
  content_pack_id TEXT NOT NULL,
  word_sense_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (content_pack_id) REFERENCES content_packs(id),
  FOREIGN KEY (word_sense_id) REFERENCES word_senses(id),
  UNIQUE(content_pack_id, word_sense_id)
);

ALTER TABLE study_events ADD COLUMN IF NOT EXISTS event_id TEXT;

UPDATE study_events
SET event_id = client_event_id
WHERE event_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_study_events_event_id
  ON study_events (event_id)
  WHERE event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_study_events_projection_order_device
  ON study_events (device_id, occurred_at DESC, received_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_study_events_projection_order_user
  ON study_events (user_id, occurred_at DESC, received_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_articles_owner_created
  ON articles (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_articles_status_created
  ON articles (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_article_processing_jobs_status_queued
  ON article_processing_jobs (status, queued_at);

CREATE INDEX IF NOT EXISTS idx_word_senses_status_level
  ON word_senses (status, level_scale, level);

CREATE INDEX IF NOT EXISTS idx_vocabulary_review_items_status_created
  ON vocabulary_review_items (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_content_packs_language_version
  ON content_packs (language, version DESC);
