-- Add attempt count columns to memorization_passages for retry tracking.
-- Workers use these to enforce max-attempts logic; retry endpoints reset them to 0.

ALTER TABLE memorization_passages
  ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE memorization_passages
  ADD COLUMN IF NOT EXISTS enrichment_attempt_count INTEGER NOT NULL DEFAULT 0;
