// Proficiency ladder progression shared by both stores: how a run of ratings
// moves the learner's level and how the proficiency state is reported.

import {
  PROFICIENCY_LEVEL_UP_THRESHOLD,
  decrementLevel,
  getDefaultProficiencyLevel,
  getProficiencyProfile,
  incrementLevel,
  isProgressionRating,
  normalizeDifficultyLevel
} from '../proficiency.js';

/** Number of most-recent events (newest first) that share `rating`. */
export function countLeadingRatings(recentEvents, rating) {
  let count = 0;
  for (const event of recentEvents) {
    if (event.rating !== rating) {
      break;
    }
    count += 1;
  }
  return count;
}

// "Many words wrong" rule: of the last MISS_WINDOW ladder ratings since the level last changed,
// MISS_THRESHOLD or more `too_hard` (did not know the word) move the learner down one level.
const MISS_WINDOW = 10;
const MISS_THRESHOLD = 6;

/**
 * Level change triggered by the newest rating, or null:
 * - every 5th consecutive `too_easy` moves up, every 5th consecutive `hard` moves down;
 * - 6 `too_hard` among the last 10 ratings received since the last level change move down. The window
 *   restarts after every change, so one bad stretch never drops a learner two levels at once.
 *
 * @param {Array}  input.recentEvents   - the learner's latest ladder events, newest first (at least 10)
 * @param {string} input.levelChangedAt - when the rating behind the last level change occurred (or null)
 */
export function planLevelChange({ rating, recentEvents, levelChangedAt, currentLevel, language }) {
  const previousLevel = normalizeDifficultyLevel(currentLevel, { language }) ?? getDefaultProficiencyLevel({ language });
  const change = (nextLevel, triggeredBy) => ({
    nextLevel,
    levelChanged: nextLevel !== previousLevel,
    previousLevel,
    triggeredBy
  });

  const consecutiveCount = countLeadingRatings(recentEvents, rating);
  if (isProgressionRating(rating) && consecutiveCount > 0 && consecutiveCount % PROFICIENCY_LEVEL_UP_THRESHOLD === 0) {
    const nextLevel =
      rating === 'too_easy' ? incrementLevel(previousLevel, { language }) : decrementLevel(previousLevel, { language });
    return change(nextLevel, `${consecutiveCount}x consecutive ${rating}`);
  }

  if (rating === 'too_hard') {
    // By occurrence, not arrival: one offline sync delivers many events in the same millisecond.
    const changedAtMs = levelChangedAt ? new Date(levelChangedAt).getTime() : -Infinity;
    const window = recentEvents
      .filter((event) => new Date(event.occurred_at).getTime() > changedAtMs)
      .slice(0, MISS_WINDOW);
    const misses = window.filter((event) => event.rating === 'too_hard').length;
    if (misses >= MISS_THRESHOLD) {
      return change(decrementLevel(previousLevel, { language }), `${misses} of last ${window.length} too_hard`);
    }
  }
  return null;
}

/** API shape of the learner's proficiency, given the stored row and the newest-first recent events. */
export function toProficiencyResponse({
  proficiency,
  recentEvents,
  userId = null,
  language = 'en',
  levelChanged = false,
  previousLevel = null,
  triggeredBy = null
}) {
  const currentRatingType = recentEvents[0]?.rating ?? null;
  const consecutiveCount = currentRatingType ? countLeadingRatings(recentEvents, currentRatingType) : 0;
  const profile = getProficiencyProfile({ language });
  return {
    scale: profile.scale,
    level: proficiency.level,
    level_index: profile.levels.indexOf(proficiency.level),
    level_changed: levelChanged,
    previous_level: previousLevel,
    triggered_by: triggeredBy,
    consecutive_count: levelChanged ? 0 : consecutiveCount,
    consecutive_rating_type: levelChanged ? null : currentRatingType,
    user_id: userId,
    language,
    last_updated: proficiency.updated_at
  };
}
