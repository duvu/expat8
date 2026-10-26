-- Migration: spaced-repetition memory per word (src/domain/srs.js). States are rebuilt from
-- study_events by `npm run rebuild:srs`, so existing rows need no backfill here.

ALTER TABLE user_word_states ADD COLUMN IF NOT EXISTS interval_days REAL NOT NULL DEFAULT 0;
ALTER TABLE user_word_states ADD COLUMN IF NOT EXISTS reps INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_word_states ADD COLUMN IF NOT EXISTS lapses INTEGER NOT NULL DEFAULT 0;

-- Review-state pull for the mobile app: an owner's states changed after a cursor.
CREATE INDEX IF NOT EXISTS idx_user_word_states_user_updated
  ON user_word_states (user_id, updated_at, id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_word_states_device_updated
  ON user_word_states (device_id, updated_at, id) WHERE user_id IS NULL;
-- Replaying one word's events on every rating.
CREATE INDEX IF NOT EXISTS idx_study_events_user_word ON study_events (user_id, word_id);
CREATE INDEX IF NOT EXISTS idx_study_events_device_word ON study_events (device_id, word_id);

-- When the triggering rating of the last level change occurred (domain/proficiency_progress.js):
-- the "many wrong answers" window only counts ratings after it.
ALTER TABLE user_proficiency ADD COLUMN IF NOT EXISTS level_changed_at TEXT;
