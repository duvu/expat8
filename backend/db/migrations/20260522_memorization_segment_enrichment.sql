-- Migration: Add IPA transcription and translation to memorization_segments
-- Also adds enrichment_status tracking to memorization_passages

-- Add enrichment columns to memorization_segments
ALTER TABLE memorization_segments ADD COLUMN IF NOT EXISTS ipa_text TEXT;
ALTER TABLE memorization_segments ADD COLUMN IF NOT EXISTS translation_text TEXT;
ALTER TABLE memorization_segments ADD COLUMN IF NOT EXISTS translation_language TEXT;

-- Add enrichment_status to memorization_passages
ALTER TABLE memorization_passages ADD COLUMN IF NOT EXISTS enrichment_status TEXT NOT NULL DEFAULT 'none';

-- Index for enrichment worker polling
CREATE INDEX IF NOT EXISTS idx_memorization_passages_enrichment_status
  ON memorization_passages(enrichment_status);
