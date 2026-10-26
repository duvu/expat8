// Spaced-repetition scheduler (an SM-2 variant) shared by both stores.
//
// The mobile app runs the same algorithm offline (mobile/lib/src/srs/srs_scheduler.dart);
// contracts/srs_vectors.json pins both implementations to identical results.
// A word's state is a pure fold over its rated events in occurrence order, so
// the server can rebuild it whenever late (offline) events arrive.

export const SRS_DEFAULT_EASE = 2.5;
const SRS_RATINGS = new Set(['too_hard', 'hard', 'easy', 'too_easy']);
const MIN_EASE = 1.3;
const MAX_EASE = 3.0;
const MAX_INTERVAL_DAYS = 365;
const MASTERED_INTERVAL_DAYS = 21;
const RELEARN_DELAY_MS = 10 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

const round2 = (value) => Math.round(value * 100) / 100;

/** Memory of a word that was never rated. */
export function initialSrsMemory() {
  return { reps: 0, lapses: 0, ease: SRS_DEFAULT_EASE, intervalDays: 0 };
}

/**
 * Memory after one rating. `too_hard` is a lapse (forgotten: relearn in 10 minutes);
 * `hard`, `easy` and `too_easy` are successful recalls growing the interval.
 * Unknown ratings leave the memory unchanged.
 */
export function nextSrsMemory(memory, rating) {
  const { reps, lapses, ease, intervalDays } = memory;
  switch (rating) {
    case 'too_hard':
      return { reps: 0, lapses: lapses + 1, ease: round2(Math.max(MIN_EASE, ease - 0.2)), intervalDays: 0 };
    case 'hard':
      return grow(memory, Math.max(MIN_EASE, ease - 0.15), reps === 0 ? 1 : Math.max(1, intervalDays * 1.2));
    case 'easy':
      return grow(memory, ease, reps === 0 ? 2 : reps === 1 ? 6 : intervalDays * ease);
    case 'too_easy': {
      const easier = Math.min(MAX_EASE, ease + 0.15);
      return grow(memory, easier, reps === 0 ? 4 : intervalDays * easier * 1.3);
    }
    default:
      return memory;
  }
}

function grow(memory, ease, intervalDays) {
  return {
    reps: memory.reps + 1,
    lapses: memory.lapses,
    ease: round2(ease),
    intervalDays: Math.min(MAX_INTERVAL_DAYS, round2(intervalDays))
  };
}

/** When a word rated at `ratedAtMs` with this memory is due again. */
export function srsDueAtMs(memory, ratedAtMs) {
  return ratedAtMs + (memory.intervalDays === 0 ? RELEARN_DELAY_MS : Math.round(memory.intervalDays * DAY_MS));
}

/** learning (being relearned) → review → mastered (interval of three weeks or more). */
export function srsStatus(memory) {
  if (memory.intervalDays === 0) {
    return 'learning';
  }
  return memory.intervalDays >= MASTERED_INTERVAL_DAYS ? 'mastered' : 'review';
}

// Timestamps may be Date objects or ISO strings with differing offsets: compare instants.
const occurredMs = (event) => new Date(event.occurred_at).getTime();

function compareEvents(left, right) {
  return (
    occurredMs(left) - occurredMs(right) ||
    String(left.client_event_id ?? '').localeCompare(String(right.client_event_id ?? ''))
  );
}

/**
 * Rebuilds a word's SRS state from all of its rated events (any order).
 * Returns null when there is no event.
 */
export function replaySrsState(events) {
  const ordered = events.filter((event) => SRS_RATINGS.has(event.rating)).sort(compareEvents);
  if (ordered.length === 0) {
    return null;
  }
  let memory = initialSrsMemory();
  for (const event of ordered) {
    memory = nextSrsMemory(memory, event.rating);
  }
  const last = ordered.at(-1);
  const lastAtMs = occurredMs(last);
  return {
    status: srsStatus(memory),
    last_rating: last.rating,
    last_studied_at: new Date(lastAtMs).toISOString(),
    next_review_at: new Date(srsDueAtMs(memory, lastAtMs)).toISOString(),
    ease_factor: memory.ease,
    interval_days: memory.intervalDays,
    reps: memory.reps,
    lapses: memory.lapses,
    review_count: ordered.length
  };
}
