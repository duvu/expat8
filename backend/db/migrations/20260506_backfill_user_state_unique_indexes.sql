WITH ranked_anonymous_word_states AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY device_id, word_id
      ORDER BY updated_at DESC
    ) AS row_number
  FROM user_word_states
  WHERE user_id IS NULL
)
DELETE FROM user_word_states states
USING ranked_anonymous_word_states ranked
WHERE states.ctid = ranked.ctid
AND ranked.row_number > 1;

WITH ranked_user_word_states AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, word_id
      ORDER BY updated_at DESC
    ) AS row_number
  FROM user_word_states
  WHERE user_id IS NOT NULL
)
DELETE FROM user_word_states states
USING ranked_user_word_states ranked
WHERE states.ctid = ranked.ctid
AND ranked.row_number > 1;

WITH ranked_anonymous_cached_words AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY device_id, word_id
      ORDER BY updated_at DESC, observed_at DESC
    ) AS row_number
  FROM user_cached_words
  WHERE user_id IS NULL
)
DELETE FROM user_cached_words cache
USING ranked_anonymous_cached_words ranked
WHERE cache.ctid = ranked.ctid
AND ranked.row_number > 1;

WITH ranked_user_cached_words AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, word_id
      ORDER BY updated_at DESC, observed_at DESC
    ) AS row_number
  FROM user_cached_words
  WHERE user_id IS NOT NULL
)
DELETE FROM user_cached_words cache
USING ranked_user_cached_words ranked
WHERE cache.ctid = ranked.ctid
AND ranked.row_number > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_word_states_device_word
ON user_word_states(device_id, word_id)
WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_word_states_user_word
ON user_word_states(user_id, word_id)
WHERE user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_cached_words_device_word
ON user_cached_words(device_id, word_id)
WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_cached_words_user_word
ON user_cached_words(user_id, word_id)
WHERE user_id IS NOT NULL;
