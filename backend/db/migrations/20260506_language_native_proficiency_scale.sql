ALTER TABLE user_proficiency ADD COLUMN IF NOT EXISTS scale TEXT;
ALTER TABLE user_proficiency ADD COLUMN IF NOT EXISTS level_index INTEGER;

UPDATE user_proficiency
SET scale = CASE
  WHEN lower(language) LIKE 'zh%' THEN 'hsk'
  ELSE 'cefr'
END
WHERE scale IS NULL;

UPDATE user_proficiency
SET level_index = CASE
  WHEN COALESCE(scale, 'cefr') = 'hsk' THEN CASE upper(level)
    WHEN 'HSK1' THEN 0
    WHEN 'HSK2' THEN 1
    WHEN 'HSK3' THEN 2
    WHEN 'HSK4' THEN 3
    WHEN 'HSK5' THEN 4
    WHEN 'HSK6' THEN 5
    ELSE 0
  END
  ELSE CASE upper(level)
    WHEN 'A1' THEN 0
    WHEN 'A2' THEN 1
    WHEN 'B1' THEN 2
    WHEN 'B2' THEN 3
    WHEN 'C1' THEN 4
    WHEN 'C2' THEN 5
    ELSE 0
  END
END
WHERE level_index IS NULL;

ALTER TABLE user_proficiency ALTER COLUMN scale SET DEFAULT 'cefr';
ALTER TABLE user_proficiency ALTER COLUMN level_index SET DEFAULT 0;
ALTER TABLE user_proficiency ALTER COLUMN scale SET NOT NULL;
ALTER TABLE user_proficiency ALTER COLUMN level_index SET NOT NULL;
