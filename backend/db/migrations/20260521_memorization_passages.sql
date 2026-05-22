-- Migration: Memorization passages and segments
-- Adds tables for the "Học thuộc lòng" (Memorization) feature:
-- passages (source text), segments (AI-chunked pieces), and segment progress tracking.

-- Passages: the source text to be memorized
CREATE TABLE IF NOT EXISTS memorization_passages (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  language TEXT NOT NULL,
  raw_text TEXT NOT NULL,
  owner_type TEXT NOT NULL DEFAULT 'user',
  owner_user_id TEXT,
  visibility TEXT NOT NULL DEFAULT 'private',
  status TEXT NOT NULL DEFAULT 'pending_segmentation',
  processing_error TEXT,
  segment_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

-- Segments: AI-generated chunks of a passage (3-5 sentences each)
CREATE TABLE IF NOT EXISTS memorization_segments (
  id TEXT PRIMARY KEY,
  passage_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  text TEXT NOT NULL,
  word_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (passage_id) REFERENCES memorization_passages(id) ON DELETE CASCADE
);

-- Per-user, per-segment drill progress (SRS tracking)
CREATE TABLE IF NOT EXISTS memorization_segment_progress (
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

-- Indexes for passage queries
CREATE INDEX IF NOT EXISTS idx_memorization_passages_visibility_status
  ON memorization_passages(visibility, status);

CREATE INDEX IF NOT EXISTS idx_memorization_passages_owner
  ON memorization_passages(owner_user_id) WHERE owner_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_memorization_passages_status
  ON memorization_passages(status);

-- Indexes for segment queries
CREATE UNIQUE INDEX IF NOT EXISTS idx_memorization_segments_passage_position
  ON memorization_segments(passage_id, position);

-- Indexes for progress queries
CREATE UNIQUE INDEX IF NOT EXISTS idx_memorization_segment_progress_user_segment
  ON memorization_segment_progress(user_id, segment_id);

CREATE INDEX IF NOT EXISTS idx_memorization_segment_progress_user
  ON memorization_segment_progress(user_id, next_review_at);
