-- Migration: Memorization segment vocabulary links
-- Links vocabulary extracted during passage segmentation to passages and segments.

CREATE TABLE IF NOT EXISTS memorization_segment_terms (
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

CREATE INDEX IF NOT EXISTS idx_memorization_segment_terms_passage
  ON memorization_segment_terms(passage_id);

CREATE INDEX IF NOT EXISTS idx_memorization_segment_terms_segment
  ON memorization_segment_terms(segment_id);
