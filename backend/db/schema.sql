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
