// Rules of the per-owner cache of word ids held on a device (`user_word_cache`).

export const MAX_CACHED_WORD_IDS = 1000;

/** Non-empty string ids, de-duplicated in first-seen order. */
export function distinctWordIds(wordIds) {
  return [...new Set(wordIds.filter((wordId) => typeof wordId === 'string' && wordId.length > 0))];
}
