-- Partial index to speed up due-review-item queries in learningCards.
-- Only indexes rows where next_review_at is set (i.e., items pending future review).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_word_states_due
  ON user_word_states(next_review_at)
  WHERE next_review_at IS NOT NULL;
