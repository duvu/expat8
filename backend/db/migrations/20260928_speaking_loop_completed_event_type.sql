-- Migration: allow the Phase 1 `loop_completed` speaking event.
-- 20260510_speaking_drill_completed.sql re-created the event_type CHECK without
-- it, and attempt_id was NOT NULL although loop_completed carries no attempt,
-- so PostgreSQL rejected every loop completion synced by mobile.
-- attempt_id stays required at the API layer when
-- SPEAKING_EVENTS_STRICT_ATTEMPT_ID is enabled.

ALTER TABLE speaking_events ALTER COLUMN attempt_id DROP NOT NULL;

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
    'speaking_drill_completed',
    'loop_completed'
  ));
