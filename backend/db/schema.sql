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

CREATE TABLE user_word_states (
  user_id TEXT,
  device_id TEXT,
  word_id TEXT NOT NULL,
  status TEXT NOT NULL,
  last_seen_at TEXT,
  next_review_at TEXT,
  ease_factor REAL,
  review_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (word_id) REFERENCES words(id)
);

CREATE INDEX idx_words_recent ON words(created_at DESC);
CREATE INDEX idx_words_language_normalized ON words(language, normalized_term);
CREATE INDEX idx_study_events_device ON study_events(device_id, occurred_at DESC);
CREATE INDEX idx_study_events_client_event_id ON study_events(client_event_id);
CREATE INDEX idx_user_word_states_device ON user_word_states(device_id, updated_at DESC);
CREATE INDEX idx_user_word_states_user ON user_word_states(user_id, updated_at DESC);
