-- Migration: article-vocabulary-suggestion-metadata
-- Adds classification and suggestion type metadata to article vocabulary extraction rows.

ALTER TABLE article_terms ADD COLUMN IF NOT EXISTS classification TEXT;
ALTER TABLE article_terms ADD COLUMN IF NOT EXISTS suggestion_type TEXT;
