export const CEFR_LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
export const HSK_LEVELS = ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'];
export const VALID_STUDY_RATINGS = ['easy', 'too_easy', 'hard', 'too_hard'];
export const PROFICIENCY_LEVEL_UP_THRESHOLD = 5;

const PROFICIENCY_PROFILES = {
  cefr: {
    scale: 'cefr',
    levels: CEFR_LEVELS,
    defaultLevel: 'A1'
  },
  hsk: {
    scale: 'hsk',
    levels: HSK_LEVELS,
    defaultLevel: 'HSK1'
  }
};

const LANGUAGE_SCALE_ALIASES = new Map([
  ['en', 'cefr'],
  ['en-us', 'cefr'],
  ['en-gb', 'cefr'],
  ['zh', 'hsk'],
  ['zh-cn', 'hsk'],
  ['zh-hans', 'hsk'],
  ['zh-sg', 'hsk']
]);

const LEGACY_DIFFICULTY_MAP = new Map([
  ['beginner', 'A1'],
  ['elementary', 'A1'],
  ['pre-intermediate', 'A2'],
  ['intermediate', 'B1'],
  ['upper-intermediate', 'B2'],
  ['advanced', 'C1'],
  ['proficient', 'C2']
]);

export class InvalidProficiencyLevelError extends Error {
  constructor(level, scale = null) {
    const suffix = scale ? ` for scale ${scale}` : '';
    super(`invalid proficiency level: ${level}${suffix}`);
    this.name = 'InvalidProficiencyLevelError';
  }
}

export class InvalidStudyRatingError extends Error {
  constructor(rating) {
    super(`invalid study rating: ${rating}`);
    this.name = 'InvalidStudyRatingError';
  }
}

export function resolveScaleForLanguage(language = null) {
  if (typeof language !== 'string') {
    return 'cefr';
  }
  return LANGUAGE_SCALE_ALIASES.get(language.trim().toLowerCase()) ?? 'cefr';
}

export function getProficiencyProfile({ language = null, scale = null } = {}) {
  const resolvedScale =
    typeof scale === 'string' && scale.trim() ? scale.trim().toLowerCase() : resolveScaleForLanguage(language);
  return PROFICIENCY_PROFILES[resolvedScale] ?? PROFICIENCY_PROFILES.cefr;
}

export function getDefaultProficiencyLevel({ language = null, scale = null } = {}) {
  return getProficiencyProfile({ language, scale }).defaultLevel;
}

export function normalizeDifficultyLevel(value, options = {}) {
  const profile = getProficiencyProfile(options);
  if (value === undefined || value === null) {
    return null;
  }
  const trimmed = String(value).trim();
  if (!trimmed) {
    return null;
  }
  const upper = trimmed.toUpperCase();
  if (profile.levels.includes(upper)) {
    return upper;
  }
  if (profile.scale !== 'cefr') {
    return null;
  }
  return LEGACY_DIFFICULTY_MAP.get(trimmed.toLowerCase()) ?? null;
}

export function validateDifficultyLevel(value, options = {}) {
  return normalizeDifficultyLevel(value, options) !== null;
}

export function validateStudyRating(rating) {
  return VALID_STUDY_RATINGS.includes(rating);
}

export function requireStudyRating(rating) {
  if (!validateStudyRating(rating)) {
    throw new InvalidStudyRatingError(rating);
  }
  return rating;
}

export function incrementLevel(level, options = {}) {
  const profile = getProficiencyProfile(options);
  const normalized = normalizeRequiredLevel(level, profile);
  const index = profile.levels.indexOf(normalized);
  return profile.levels[Math.min(index + 1, profile.levels.length - 1)];
}

export function decrementLevel(level, options = {}) {
  const profile = getProficiencyProfile(options);
  const normalized = normalizeRequiredLevel(level, profile);
  const index = profile.levels.indexOf(normalized);
  return profile.levels[Math.max(index - 1, 0)];
}

export function getFallbackDifficultyLevels(level, options = {}) {
  const profile = getProficiencyProfile(options);
  const normalized = normalizeRequiredLevel(level, profile);
  const index = profile.levels.indexOf(normalized);
  const offsets = [0, 1, -1, -2, 2, -3, 3, -4, 4, -5, 5];
  const ordered = [];

  for (const offset of offsets) {
    const candidate = profile.levels[index + offset];
    if (candidate && !ordered.includes(candidate)) {
      ordered.push(candidate);
    }
  }

  return ordered;
}

export function isProgressionRating(rating) {
  return rating === 'too_easy' || rating === 'hard';
}

export function getLevelIndex(level, options = {}) {
  const profile = getProficiencyProfile(options);
  const normalized = normalizeDifficultyLevel(level, options);
  if (!normalized) {
    return null;
  }
  return profile.levels.indexOf(normalized);
}

function normalizeRequiredLevel(level, profile) {
  const normalized = normalizeDifficultyLevel(level, { scale: profile.scale });
  if (!normalized) {
    throw new InvalidProficiencyLevelError(level, profile.scale);
  }
  return normalized;
}

const SAME_LEVEL_SHARE = 0.8;

/**
 * Picks `count` new-card candidates for the learner: ~80% at the learner's own level, the remaining ~20%
 * at random from the levels below it (a lower level is drawn first, then a word within it, so the
 * reinforcement spreads across bands). Words inside a band are drawn at random and the final batch is
 * shuffled, so consecutive cards never arrive as a run of one level. A learner at the lowest level has
 * nothing below, so everything comes from their own level. When a band runs dry the remainder comes from
 * the nearest levels (above before below), so a B1 learner never silently falls back to A1 while B1/B2
 * words exist. Words with an unknown level rank last. `random` is injectable for tests.
 */
export function selectNewCardsByLevel(words, { level, language = null, count, random = Math.random }) {
  const profile = getProficiencyProfile({ language });
  const levelIndex = Math.max(0, profile.levels.indexOf(normalizeDifficultyLevel(level, { language }) ?? ''));
  const unknownDistance = profile.levels.length + 1;
  const entries = words.map((word) => {
    const wordIndex = profile.levels.indexOf(normalizeDifficultyLevel(word.difficulty, { language }) ?? '');
    return { word, delta: wordIndex < 0 ? unknownDistance : wordIndex - levelIndex };
  });

  const same = shuffled(entries.filter((entry) => entry.delta === 0), random);
  const belowByDelta = new Map();
  for (const entry of shuffled(entries.filter((e) => e.delta < 0 && e.delta !== -unknownDistance), random)) {
    belowByDelta.set(entry.delta, [...(belowByDelta.get(entry.delta) ?? []), entry]);
  }

  const belowQuota = Math.round(count * (1 - SAME_LEVEL_SHARE));
  const chosen = [];
  for (let taken = 0; taken < belowQuota && belowByDelta.size > 0; taken += 1) {
    const deltas = [...belowByDelta.keys()];
    const delta = deltas[Math.floor(random() * deltas.length)];
    const bucket = belowByDelta.get(delta);
    chosen.push(bucket.pop());
    if (bucket.length === 0) {
      belowByDelta.delete(delta);
    }
  }
  chosen.push(...same.slice(0, count - chosen.length));

  if (chosen.length < count) {
    const chosenWords = new Set(chosen.map((entry) => entry.word));
    const rest = entries
      .filter((entry) => !chosenWords.has(entry.word))
      .sort(
        (left, right) =>
          Math.abs(left.delta) - Math.abs(right.delta) ||
          right.delta - left.delta ||
          String(right.word.created_at ?? '').localeCompare(String(left.word.created_at ?? ''))
      );
    chosen.push(...rest.slice(0, count - chosen.length));
  }
  return shuffled(chosen, random)
    .slice(0, count)
    .map((entry) => entry.word);
}

function shuffled(items, random) {
  const result = [...items];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swap = Math.floor(random() * (index + 1));
    [result[index], result[swap]] = [result[swap], result[index]];
  }
  return result;
}
