// Incremental pull of a learner's SRS states (GET /v1/review/states), shared by both stores.
// The mobile app keeps a cursor per account and language and asks only for states changed since.

import { toApiWord } from './vocabulary.js';

/** Opaque cursor: the (updated_at, id) of the last state a client received. */
export function encodeReviewCursor(state) {
  return Buffer.from(JSON.stringify([state.updated_at, state.id])).toString('base64url');
}

/** Decoded cursor, or null when absent or malformed (= start from the beginning). */
export function decodeReviewCursor(raw) {
  if (typeof raw !== 'string' || raw === '') {
    return null;
  }
  try {
    const [updatedAt, id] = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    return typeof updatedAt === 'string' && typeof id === 'string' ? { updatedAt, id } : null;
  } catch {
    return null;
  }
}

/** Whether a state sorts after the cursor in (updated_at, id) order. */
export function isAfterReviewCursor(state, cursor) {
  if (!cursor) {
    return true;
  }
  return state.updated_at > cursor.updatedAt || (state.updated_at === cursor.updatedAt && state.id > cursor.id);
}

/**
 * API page: each state with its word, the cursor to send next time (the last row's, or the request's
 * when nothing changed), and whether another page is waiting.
 */
export function toReviewStatesPage({ rows, limit, requestCursor = null }) {
  const items = rows
    .filter((row) => row.word)
    .map(({ state, word }) => ({
      word: toApiWord(word),
      state: {
        status: state.status,
        last_rating: state.last_rating,
        last_studied_at: state.last_studied_at,
        next_review_at: state.next_review_at,
        ease: state.ease_factor,
        interval_days: state.interval_days,
        reps: state.reps,
        lapses: state.lapses,
        review_count: state.review_count,
        updated_at: state.updated_at
      }
    }));
  return {
    items,
    next_cursor: rows.length > 0 ? encodeReviewCursor(rows.at(-1).state) : requestCursor,
    has_more: rows.length === limit
  };
}
