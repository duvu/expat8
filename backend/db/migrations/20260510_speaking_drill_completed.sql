-- Migration: speaking-drill-completed
-- 1. Make speaking_prompts.word_sense_id nullable (general seed prompts need not be tied to a word sense).
-- 2. Extend speaking_events with speaking_drill_completed type and new drill metadata columns.
-- 3. Add composite index on speaking_events(device_id, event_type, occurred_at) for analytics.

-- Drop the old CHECK constraint on speaking_prompts.word_sense_id (NOT NULL)
ALTER TABLE speaking_prompts ALTER COLUMN word_sense_id DROP NOT NULL;

-- Add drill metadata columns to speaking_events
ALTER TABLE speaking_events ADD COLUMN IF NOT EXISTS prompts_attempted INTEGER;
ALTER TABLE speaking_events ADD COLUMN IF NOT EXISTS prompts_completed INTEGER;
ALTER TABLE speaking_events ADD COLUMN IF NOT EXISTS total_duration_ms INTEGER;

-- Extend the event_type CHECK constraint to include speaking_drill_completed.
-- PostgreSQL auto-names inline CHECK constraints; drop and re-add.
ALTER TABLE speaking_events
  DROP CONSTRAINT IF EXISTS speaking_events_event_type_check;

ALTER TABLE speaking_events
  ADD CONSTRAINT speaking_events_event_type_check CHECK (event_type IN (
    'speaking_prompt_viewed',
    'speaking_sample_played',
    'speaking_recorded',
    'speaking_retried',
    'speaking_self_rated_clear',
    'speaking_self_rated_hesitated',
    'speaking_self_rated_could_not_say',
    'speaking_drill_completed'
  ));

-- Composite index on speaking_events for speaking-summary analytics.
-- Note: study_events has no event_type column; all speaking events live in speaking_events.
CREATE INDEX IF NOT EXISTS idx_speaking_events_device_type_occurred
  ON speaking_events (device_id, event_type, occurred_at DESC);
