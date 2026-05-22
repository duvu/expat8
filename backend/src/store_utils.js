/**
 * Shared utility functions for store implementations.
 * Used by both WordStore (in-memory) and PostgresWordStore.
 */

export function statusForRating(rating) {
  if (rating === 'easy' || rating === 'too_easy') {
    return 'completed';
  }
  return rating === 'too_hard' ? 'learning' : 'review';
}

export function nextReviewForRating(rating, occurredAt) {
  if (rating === 'easy' || rating === 'too_easy') {
    return null;
  }
  if (rating === 'too_hard') {
    return new Date(occurredAt.getTime() + 5 * 60 * 1000);
  }
  return new Date(occurredAt.getTime() + 24 * 60 * 60 * 1000);
}

export function normalizeWeekStart(value) {
  if (typeof value === 'string' && value.trim()) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }
  const now = new Date();
  const day = now.getUTCDay();
  const diff = day === 0 ? 6 : day - 1;
  now.setUTCDate(now.getUTCDate() - diff);
  now.setUTCHours(0, 0, 0, 0);
  return now.toISOString();
}
