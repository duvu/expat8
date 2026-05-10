-- Migration: add-vocabulary-exam
-- Adds exam session, question, attempt, and certificate tables for the
-- vocabulary quiz feature. Uses the existing `words` and `users` tables.
-- No changes to user_word_states or SRS state.

CREATE TABLE IF NOT EXISTS exam_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  topic TEXT NOT NULL,
  language TEXT NOT NULL,
  difficulty_level TEXT,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  submitted_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS exam_questions (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  word_id TEXT NOT NULL,
  prompt_word TEXT NOT NULL,
  choices_json TEXT NOT NULL,
  correct_index INTEGER NOT NULL,
  ordinal INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES exam_sessions(id),
  FOREIGN KEY (word_id) REFERENCES words(id),
  CHECK (correct_index >= 0 AND correct_index <= 3),
  CHECK (ordinal >= 0)
);

CREATE TABLE IF NOT EXISTS exam_attempts (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  topic TEXT NOT NULL,
  language TEXT NOT NULL,
  difficulty_level TEXT,
  total_questions INTEGER NOT NULL,
  correct_count INTEGER NOT NULL,
  score_pct REAL NOT NULL,
  passed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES exam_sessions(id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  UNIQUE (session_id),
  CHECK (correct_count >= 0),
  CHECK (score_pct >= 0 AND score_pct <= 100),
  CHECK (passed IN (0, 1))
);

CREATE TABLE IF NOT EXISTS exam_certificates (
  id TEXT PRIMARY KEY,
  attempt_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  topic TEXT NOT NULL,
  language TEXT NOT NULL,
  difficulty_level TEXT,
  score_pct REAL NOT NULL,
  issued_at TEXT NOT NULL,
  FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  UNIQUE (attempt_id)
);

-- Index for per-user result history queries (newest first).
CREATE INDEX IF NOT EXISTS idx_exam_attempts_user_created
  ON exam_attempts(user_id, created_at DESC);

-- Index for question lookup by session (used on submit).
CREATE INDEX IF NOT EXISTS idx_exam_questions_session
  ON exam_questions(session_id, ordinal);

-- Index for session expiry / duplicate submission checks.
CREATE INDEX IF NOT EXISTS idx_exam_sessions_user
  ON exam_sessions(user_id, created_at DESC);
