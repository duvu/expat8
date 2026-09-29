-- Permanently delete one learner account (or one anonymous device) and
-- everything tied to it.
--
-- Usage (connect directly to PostgreSQL, not through pgbouncer):
--   psql "$DIRECT_DATABASE_URL" -v user_id=user_abc -v confirm=yes -f backend/db/ops/delete_user.sql
--   psql "$DIRECT_DATABASE_URL" -v device_id=device_abc -v confirm=yes -f backend/db/ops/delete_user.sql
--
-- Without -v confirm=yes the script prints what it would delete and rolls back.
--
-- Deleted: the users row, sessions, proficiency, study/speaking/game/exam
-- history, word states and caches, submitted words, and content the learner
-- owns (articles, memorization passages, shadowing entries). Data recorded
-- anonymously on the learner's devices (device_id seen in user_sessions) is
-- deleted too. Admin-owned content the learner reviewed is kept; only the
-- reviewer reference is cleared.
\set ON_ERROR_STOP on
\if :{?user_id}
\else
  \set user_id ''
\endif
\if :{?device_id}
\else
  \set device_id ''
\endif
SELECT (:'user_id' = '' AND :'device_id' = '') AS missing_target \gset
\if :missing_target
  \echo 'pass -v user_id=<id> or -v device_id=<id>'
  \quit
\endif

BEGIN;

CREATE TEMP TABLE del_user ON COMMIT DROP AS
SELECT id FROM users WHERE id = :'user_id';

CREATE TEMP TABLE del_devices ON COMMIT DROP AS
SELECT DISTINCT device_id FROM user_sessions
WHERE user_id IN (SELECT id FROM del_user) AND device_id IS NOT NULL
UNION
SELECT :'device_id' WHERE :'device_id' <> '';

SELECT (SELECT count(*) FROM del_user) AS users_matched,
       (SELECT string_agg(device_id, ', ') FROM del_devices) AS devices;

CREATE TEMP TABLE del_articles ON COMMIT DROP AS
SELECT id FROM articles WHERE owner_user_id IN (SELECT id FROM del_user);

CREATE TEMP TABLE del_senses ON COMMIT DROP AS
SELECT DISTINCT word_sense_id AS id FROM article_terms
WHERE article_id IN (SELECT id FROM del_articles) AND word_sense_id IS NOT NULL
UNION
SELECT DISTINCT t.word_sense_id FROM memorization_segment_terms t
JOIN memorization_passages p ON p.id = t.passage_id
WHERE p.owner_user_id IN (SELECT id FROM del_user) AND t.word_sense_id IS NOT NULL;

CREATE TEMP TABLE del_exam_sessions ON COMMIT DROP AS
SELECT id FROM exam_sessions WHERE user_id IN (SELECT id FROM del_user);

-- Content owned by the learner ------------------------------------------------
UPDATE speaking_prompts SET article_term_id = NULL
WHERE article_term_id IN (SELECT id FROM article_terms WHERE article_id IN (SELECT id FROM del_articles));
DELETE FROM vocabulary_review_items WHERE article_id IN (SELECT id FROM del_articles);
DELETE FROM article_terms WHERE article_id IN (SELECT id FROM del_articles);
DELETE FROM article_workplace_sentences WHERE article_id IN (SELECT id FROM del_articles);
DELETE FROM workplace_sentences ws
WHERE NOT EXISTS (SELECT 1 FROM article_workplace_sentences a WHERE a.workplace_sentence_id = ws.id);
DELETE FROM article_processing_jobs WHERE article_id IN (SELECT id FROM del_articles);
DELETE FROM articles WHERE id IN (SELECT id FROM del_articles);

-- Segments, segment terms and segment progress cascade from the passage.
DELETE FROM memorization_passages WHERE owner_user_id IN (SELECT id FROM del_user);

-- Word senses created only for the deleted content.
DELETE FROM vocabulary_review_items WHERE word_sense_id IN (SELECT id FROM del_senses);
DELETE FROM word_senses s
WHERE s.id IN (SELECT id FROM del_senses)
  AND NOT EXISTS (SELECT 1 FROM article_terms x WHERE x.word_sense_id = s.id)
  AND NOT EXISTS (SELECT 1 FROM memorization_segment_terms x WHERE x.word_sense_id = s.id)
  AND NOT EXISTS (SELECT 1 FROM content_pack_items x WHERE x.word_sense_id = s.id)
  AND NOT EXISTS (SELECT 1 FROM speaking_prompts x WHERE x.word_sense_id = s.id)
  AND NOT EXISTS (SELECT 1 FROM speaking_events x WHERE x.word_sense_id = s.id);

DELETE FROM shadowing_video_entries
WHERE owner_user_id IN (SELECT id FROM del_user)
   OR owner_device_id IN (SELECT device_id FROM del_devices);

-- Learning history (account and the account's devices) -----------------------
DELETE FROM exam_certificates WHERE user_id IN (SELECT id FROM del_user)
   OR attempt_id IN (SELECT id FROM exam_attempts WHERE session_id IN (SELECT id FROM del_exam_sessions));
DELETE FROM exam_attempts WHERE user_id IN (SELECT id FROM del_user)
   OR session_id IN (SELECT id FROM del_exam_sessions);
DELETE FROM exam_questions WHERE session_id IN (SELECT id FROM del_exam_sessions);
DELETE FROM exam_sessions WHERE id IN (SELECT id FROM del_exam_sessions);

DELETE FROM memorization_segment_progress WHERE user_id IN (SELECT id FROM del_user);
DELETE FROM user_submitted_word_jobs WHERE submission_id IN
  (SELECT id FROM user_submitted_words WHERE user_id IN (SELECT id FROM del_user));
DELETE FROM user_submitted_words WHERE user_id IN (SELECT id FROM del_user);

DELETE FROM speaking_events WHERE user_id IN (SELECT id FROM del_user)
   OR device_id IN (SELECT device_id FROM del_devices);
DELETE FROM study_events WHERE user_id IN (SELECT id FROM del_user)
   OR device_id IN (SELECT device_id FROM del_devices);
DELETE FROM game_rounds WHERE user_id IN (SELECT id FROM del_user)
   OR device_id IN (SELECT device_id FROM del_devices);
DELETE FROM user_word_states WHERE user_id IN (SELECT id FROM del_user)
   OR device_id IN (SELECT device_id FROM del_devices);
DELETE FROM user_cached_words WHERE user_id IN (SELECT id FROM del_user)
   OR device_id IN (SELECT device_id FROM del_devices);
DELETE FROM user_proficiency WHERE user_id IN (SELECT id FROM del_user)
   OR device_id IN (SELECT device_id FROM del_devices);

-- Keep admin-owned content, drop the reference to this reviewer.
UPDATE vocabulary_review_items SET reviewer_user_id = NULL WHERE reviewer_user_id IN (SELECT id FROM del_user);
UPDATE speaking_prompts SET reviewer_user_id = NULL WHERE reviewer_user_id IN (SELECT id FROM del_user);

-- The account itself -----------------------------------------------------------
DELETE FROM user_sessions WHERE user_id IN (SELECT id FROM del_user);
DELETE FROM users WHERE id IN (SELECT id FROM del_user);

SELECT (SELECT count(*) FROM users WHERE id = :'user_id') AS remaining_user_rows,
       (SELECT count(*) FROM study_events WHERE device_id IN (SELECT device_id FROM del_devices)) AS remaining_device_events;

\if :{?confirm}
  \if :confirm
    COMMIT;
    \echo 'deleted (committed)'
  \else
    ROLLBACK;
    \echo 'dry run: rolled back (pass -v confirm=yes to delete)'
  \endif
\else
  ROLLBACK;
  \echo 'dry run: rolled back (pass -v confirm=yes to delete)'
\endif
