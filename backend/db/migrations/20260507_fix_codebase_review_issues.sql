-- Migration: fix-codebase-review-issues
-- Adds missing index on user_word_states(word_id) for JOIN performance.

CREATE INDEX IF NOT EXISTS idx_user_word_states_word_id ON user_word_states(word_id);
