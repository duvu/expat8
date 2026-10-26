// The learning-card mix (due reviews + new words) shared by both stores. Scheduling lives in srs.js.

import { selectNewCardsByLevel } from '../proficiency.js';
import { clampLimit } from './pagination.js';

// Share of a batch reserved for due reviews; the rest (and any unused review slots) go to new words.
const REVIEW_SHARE = 0.85;
const MAX_CARDS = 100;

/**
 * Builds a learning batch: due reviews first (soonest due first, up to the
 * review share), then new words picked around the learner's level. New
 * candidates exclude words already cached on the device or already studied.
 *
 * @param {object} input
 * @param {Map}    input.wordById       - word lookup for due states
 * @param {Array}  input.candidateWords - words of the target language
 * @param {Array}  input.states         - owner's word states for the target language
 * @param {Set}    input.cachedWordIds  - words the owner's device already holds
 */
export function composeLearningCards({ wordById, candidateWords, states, cachedWordIds, level, language, limit, now }) {
  const cappedLimit = clampLimit(limit, MAX_CARDS);
  const targetReview = Math.floor(cappedLimit * REVIEW_SHARE);
  const studiedWordIds = new Set(states.map((state) => state.word_id));

  const reviewCards = states
    .filter((state) => state.next_review_at && state.next_review_at <= now)
    .sort((a, b) => a.next_review_at.localeCompare(b.next_review_at))
    .slice(0, targetReview)
    .map((state) => {
      const word = wordById.get(state.word_id);
      return word ? { word, cardType: 'review', selectionReason: 'srs_due' } : null;
    })
    .filter(Boolean);

  const newCandidates = candidateWords.filter((word) => !cachedWordIds.has(word.id) && !studiedWordIds.has(word.id));
  const newCards = selectNewCardsByLevel(newCandidates, {
    level,
    language,
    count: cappedLimit - reviewCards.length
  }).map((word) => ({ word, cardType: 'new', selectionReason: 'new_available' }));

  return {
    level,
    items: [...reviewCards, ...newCards],
    target_mix: { new: cappedLimit - targetReview, review: targetReview },
    actual_mix: { new: newCards.length, review: reviewCards.length }
  };
}

/** Ids of the new words in a batch; the store remembers them as cached on the device. */
export function newCardWordIds(batch) {
  return batch.items.filter((card) => card.cardType === 'new').map((card) => card.word.id);
}
