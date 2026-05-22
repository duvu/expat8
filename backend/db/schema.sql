CREATE TABLE words (
  id TEXT PRIMARY KEY,
  term TEXT NOT NULL,
  normalized_term TEXT NOT NULL,
  language TEXT NOT NULL,
  meaning_vi TEXT NOT NULL,
  part_of_speech TEXT,
  ipa TEXT NOT NULL,
  vietnamese_pronunciation TEXT NOT NULL,
  example TEXT NOT NULL,
  example_vi TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  topics_json TEXT NOT NULL,
  entry_type TEXT NOT NULL DEFAULT 'word',
  blank_word TEXT,
  explanation TEXT NOT NULL DEFAULT '',
  generation_source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(language, normalized_term)
);

CREATE TABLE study_events (
  id TEXT PRIMARY KEY,
  client_event_id TEXT NOT NULL UNIQUE,
  device_id TEXT NOT NULL,
  user_id TEXT,
  word_id TEXT,
  local_word_id TEXT,
  rating TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  received_at TEXT NOT NULL,
  FOREIGN KEY (word_id) REFERENCES words(id)
);

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  identifier TEXT NOT NULL UNIQUE,
  display_name TEXT,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE user_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  device_id TEXT,
  created_at TEXT NOT NULL,
  revoked_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE user_proficiency (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  device_id TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',
  level TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE user_word_states (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  device_id TEXT,
  word_id TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',
  status TEXT NOT NULL,
  last_rating TEXT,
  last_studied_at TEXT,
  next_review_at TEXT,
  ease_factor REAL,
  review_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (word_id) REFERENCES words(id)
);

CREATE TABLE generation_runs (
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

CREATE TABLE scheduler_locks (
  target_language TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE user_cached_words (
  device_id TEXT NOT NULL,
  user_id TEXT,
  word_id TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (word_id) REFERENCES words(id)
);

CREATE TABLE articles (
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

CREATE TABLE article_processing_jobs (
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

CREATE TABLE workplace_sentences (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  normalized_text TEXT NOT NULL,
  language TEXT NOT NULL,
  meaning_vi TEXT NOT NULL,
  topic TEXT,
  generation_source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(language, normalized_text)
);

CREATE TABLE article_workplace_sentences (
  id TEXT PRIMARY KEY,
  article_id TEXT NOT NULL,
  workplace_sentence_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(article_id, workplace_sentence_id),
  FOREIGN KEY (article_id) REFERENCES articles(id),
  FOREIGN KEY (workplace_sentence_id) REFERENCES workplace_sentences(id)
);

CREATE TABLE terms (
  id TEXT PRIMARY KEY,
  language TEXT NOT NULL,
  display_term TEXT NOT NULL,
  normalized_term TEXT NOT NULL,
  lemma TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(language, normalized_term)
);

CREATE TABLE word_senses (
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

CREATE TABLE article_terms (
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
  classification TEXT,
  suggestion_type TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (article_id) REFERENCES articles(id),
  FOREIGN KEY (term_id) REFERENCES terms(id),
  FOREIGN KEY (word_sense_id) REFERENCES word_senses(id)
);

CREATE TABLE vocabulary_review_items (
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

CREATE INDEX idx_words_recent ON words(created_at DESC);
CREATE INDEX idx_words_language_normalized ON words(language, normalized_term);
CREATE INDEX idx_study_events_device ON study_events(device_id, occurred_at DESC);
CREATE INDEX idx_study_events_user ON study_events(user_id, occurred_at DESC);
CREATE INDEX idx_study_events_client_event_id ON study_events(client_event_id);
CREATE INDEX idx_users_identifier ON users(identifier);
CREATE INDEX idx_user_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX idx_user_sessions_user ON user_sessions(user_id, created_at DESC);
CREATE UNIQUE INDEX idx_user_proficiency_device_language
  ON user_proficiency(device_id, language)
  WHERE user_id IS NULL;
CREATE UNIQUE INDEX idx_user_proficiency_user_language
  ON user_proficiency(user_id, language)
  WHERE user_id IS NOT NULL;
CREATE INDEX idx_user_word_states_device ON user_word_states(device_id, updated_at DESC);
CREATE INDEX idx_user_word_states_user ON user_word_states(user_id, updated_at DESC);
CREATE UNIQUE INDEX idx_user_word_states_device_word ON user_word_states(device_id, word_id) WHERE user_id IS NULL;
CREATE UNIQUE INDEX idx_user_word_states_user_word ON user_word_states(user_id, word_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_user_word_states_due ON user_word_states(next_review_at) WHERE next_review_at IS NOT NULL;
CREATE INDEX idx_generation_runs_language_date ON generation_runs(target_language, mode, run_date);
CREATE INDEX idx_user_cached_words_device ON user_cached_words(device_id, updated_at DESC);
CREATE INDEX idx_user_cached_words_user ON user_cached_words(user_id, updated_at DESC);
CREATE UNIQUE INDEX idx_user_cached_words_device_word ON user_cached_words(device_id, word_id) WHERE user_id IS NULL;
CREATE UNIQUE INDEX idx_user_cached_words_user_word ON user_cached_words(user_id, word_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_user_submitted_words_device_updated ON user_submitted_words(device_id, updated_at DESC);
CREATE INDEX idx_user_submitted_words_user_updated ON user_submitted_words(user_id, updated_at DESC) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX idx_user_submitted_words_active_device_term
  ON user_submitted_words(device_id, language, normalized_term)
  WHERE user_id IS NULL AND status IN ('queued', 'processing');
CREATE UNIQUE INDEX idx_user_submitted_words_active_user_term
  ON user_submitted_words(user_id, language, normalized_term)
  WHERE user_id IS NOT NULL AND status IN ('queued', 'processing');
CREATE INDEX idx_user_submitted_words_resolved_word ON user_submitted_words(resolved_word_id) WHERE resolved_word_id IS NOT NULL;
CREATE INDEX idx_user_submitted_word_jobs_status_queued ON user_submitted_word_jobs(status, queued_at);
CREATE INDEX idx_workplace_sentences_language_updated ON workplace_sentences(language, updated_at DESC);
CREATE INDEX idx_article_workplace_sentences_article ON article_workplace_sentences(article_id);
CREATE INDEX idx_article_workplace_sentences_sentence ON article_workplace_sentences(workplace_sentence_id);

CREATE TABLE release_versions (
  id TEXT PRIMARY KEY,
  platform TEXT NOT NULL,
  version_code INTEGER NOT NULL,
  version_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX idx_release_versions_platform_code ON release_versions(platform, version_code DESC);

CREATE TABLE memorization_passages (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  language TEXT NOT NULL,
  raw_text TEXT NOT NULL,
  owner_type TEXT NOT NULL DEFAULT 'user',
  owner_user_id TEXT,
  visibility TEXT NOT NULL DEFAULT 'private',
  status TEXT NOT NULL DEFAULT 'pending_segmentation',
  enrichment_status TEXT NOT NULL DEFAULT 'none',
  processing_error TEXT,
  segment_count INTEGER NOT NULL DEFAULT 0,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  enrichment_attempt_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE TABLE memorization_segments (
  id TEXT PRIMARY KEY,
  passage_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  text TEXT NOT NULL,
  word_count INTEGER NOT NULL DEFAULT 0,
  ipa_text TEXT,
  translation_text TEXT,
  translation_language TEXT,
  viet_reading_text TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (passage_id) REFERENCES memorization_passages(id) ON DELETE CASCADE
);

CREATE TABLE memorization_segment_progress (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  segment_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'new',
  review_count INTEGER NOT NULL DEFAULT 0,
  ease_factor REAL NOT NULL DEFAULT 2.5,
  last_reviewed_at TEXT,
  next_review_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (segment_id) REFERENCES memorization_segments(id) ON DELETE CASCADE
);

CREATE TABLE memorization_segment_terms (
  id TEXT PRIMARY KEY,
  passage_id TEXT NOT NULL,
  segment_id TEXT NOT NULL,
  term_id TEXT NOT NULL,
  word_sense_id TEXT,
  surface_text TEXT NOT NULL,
  sentence_context TEXT,
  frequency INTEGER NOT NULL DEFAULT 1,
  extraction_confidence REAL,
  classification TEXT,
  suggestion_type TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (passage_id) REFERENCES memorization_passages(id) ON DELETE CASCADE,
  FOREIGN KEY (segment_id) REFERENCES memorization_segments(id) ON DELETE CASCADE,
  FOREIGN KEY (term_id) REFERENCES terms(id),
  FOREIGN KEY (word_sense_id) REFERENCES word_senses(id)
);

CREATE INDEX idx_memorization_passages_visibility_status ON memorization_passages(visibility, status);
CREATE INDEX idx_memorization_passages_enrichment_status ON memorization_passages(enrichment_status);
CREATE INDEX idx_memorization_passages_owner ON memorization_passages(owner_user_id) WHERE owner_user_id IS NOT NULL;
CREATE INDEX idx_memorization_passages_status ON memorization_passages(status);
CREATE UNIQUE INDEX idx_memorization_segments_passage_position ON memorization_segments(passage_id, position);
CREATE UNIQUE INDEX idx_memorization_segment_progress_user_segment ON memorization_segment_progress(user_id, segment_id);
CREATE INDEX idx_memorization_segment_progress_user ON memorization_segment_progress(user_id, next_review_at);
CREATE INDEX idx_memorization_segment_terms_passage ON memorization_segment_terms(passage_id);
CREATE INDEX idx_memorization_segment_terms_segment ON memorization_segment_terms(segment_id);
