-- Migration: Device state claim support indexes
-- Adds indexes to efficiently find claimable device-only records during auth.

-- Index for finding all word states for a device that have no user assigned
CREATE INDEX IF NOT EXISTS idx_user_word_states_device_unclaimed
  ON user_word_states (device_id) WHERE user_id IS NULL;

-- Index for finding all cached words for a device that have no user assigned
CREATE INDEX IF NOT EXISTS idx_user_cached_words_device_unclaimed
  ON user_cached_words (device_id) WHERE user_id IS NULL;
