-- Migration: phrase-idiom-exam
-- Extends the words table with entry_type (word|phrase|idiom) and explanation
-- so phrases and idioms can be stored with contextual meaning descriptions.
-- Both columns use safe non-null defaults, so existing rows are unaffected.

ALTER TABLE words ADD COLUMN IF NOT EXISTS entry_type TEXT NOT NULL DEFAULT 'word';
ALTER TABLE words ADD COLUMN IF NOT EXISTS explanation TEXT NOT NULL DEFAULT '';
