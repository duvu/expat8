WITH ranked_user_proficiency AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, language
      ORDER BY updated_at DESC, created_at DESC
    ) AS row_number
  FROM user_proficiency
  WHERE user_id IS NOT NULL
)
DELETE FROM user_proficiency proficiency
USING ranked_user_proficiency ranked
WHERE proficiency.ctid = ranked.ctid
AND ranked.row_number > 1;

WITH ranked_anonymous_proficiency AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY device_id, language
      ORDER BY updated_at DESC, created_at DESC
    ) AS row_number
  FROM user_proficiency
  WHERE user_id IS NULL
)
DELETE FROM user_proficiency proficiency
USING ranked_anonymous_proficiency ranked
WHERE proficiency.ctid = ranked.ctid
AND ranked.row_number > 1;

ALTER TABLE user_proficiency
  DROP CONSTRAINT IF EXISTS user_proficiency_device_id_language_key;

DROP INDEX IF EXISTS idx_user_proficiency_device_language;
DROP INDEX IF EXISTS idx_user_proficiency_user_language;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_proficiency_device_language
ON user_proficiency(device_id, language)
WHERE user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_proficiency_user_language
ON user_proficiency(user_id, language)
WHERE user_id IS NOT NULL;
