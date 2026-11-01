import crypto from 'node:crypto';

export const MIN_PASSWORD_LENGTH = 8;

// No 0/O/1/l/I so a temporary password can be read out or typed without doubt.
const TEMPORARY_PASSWORD_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const TEMPORARY_PASSWORD_LENGTH = 16;

export function isAcceptablePassword(password) {
  return typeof password === 'string' && password.length >= MIN_PASSWORD_LENGTH;
}

export function generateTemporaryPassword(length = TEMPORARY_PASSWORD_LENGTH) {
  let password = '';
  for (let i = 0; i < length; i += 1) {
    password += TEMPORARY_PASSWORD_ALPHABET[crypto.randomInt(TEMPORARY_PASSWORD_ALPHABET.length)];
  }
  return password;
}

/**
 * Decides the password for an admin reset: a supplied one must pass the same
 * rule as registration, otherwise a temporary one is generated.
 * Returns null when the supplied password is unacceptable.
 */
export function resolveResetPassword(requested) {
  if (requested === undefined || requested === null || requested === '') {
    return { password: generateTemporaryPassword(), generated: true };
  }
  return isAcceptablePassword(requested) ? { password: requested, generated: false } : null;
}

/** Fat-finger guard: the caller must repeat the user's identifier exactly (case-insensitive, trimmed). */
export function deletionConfirmed(user, confirm) {
  return typeof confirm === 'string' && confirm.trim().toLowerCase() === user.identifier;
}

/**
 * Columns that reference a user. Account deletion handles every entry; the
 * Postgres integration test fails when a foreign key to users(id) is missing
 * here, so a new table cannot silently survive an account deletion.
 * `clear` keeps shared admin content and only nulls the reference.
 */
export const USER_REFERENCES = [
  { table: 'user_sessions', column: 'user_id', action: 'delete' },
  { table: 'user_proficiency', column: 'user_id', action: 'delete' },
  { table: 'user_word_states', column: 'user_id', action: 'delete' },
  { table: 'user_cached_words', column: 'user_id', action: 'delete' },
  { table: 'user_submitted_words', column: 'user_id', action: 'delete' },
  { table: 'study_events', column: 'user_id', action: 'delete' },
  { table: 'speaking_events', column: 'user_id', action: 'delete' },
  { table: 'game_rounds', column: 'user_id', action: 'delete' },
  { table: 'exam_sessions', column: 'user_id', action: 'delete' },
  { table: 'exam_attempts', column: 'user_id', action: 'delete' },
  { table: 'exam_certificates', column: 'user_id', action: 'delete' },
  { table: 'articles', column: 'owner_user_id', action: 'delete' },
  { table: 'memorization_passages', column: 'owner_user_id', action: 'delete' },
  { table: 'memorization_segment_progress', column: 'user_id', action: 'delete' },
  { table: 'shadowing_video_entries', column: 'owner_user_id', action: 'delete' },
  { table: 'vocabulary_review_items', column: 'reviewer_user_id', action: 'clear' },
  { table: 'speaking_prompts', column: 'reviewer_user_id', action: 'clear' }
];

/** Row counts reported by a deletion, grouped for readability. */
export const DELETION_SUMMARY_KEYS = [
  'user',
  'sessions',
  'proficiency',
  'study_events',
  'speaking_events',
  'game_rounds',
  'exam_rows',
  'word_states',
  'cached_words',
  'submitted_words',
  'articles',
  'memorization_content',
  'memorization_progress',
  'shadowing_entries',
  'cleared_reviewer_refs'
];

export function emptyDeletionSummary() {
  return Object.fromEntries(DELETION_SUMMARY_KEYS.map((key) => [key, 0]));
}
