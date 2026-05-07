export const CEFR_LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
export const HSK_LEVELS = ['HSK1', 'HSK2', 'HSK3', 'HSK4', 'HSK5', 'HSK6'];
export const DEFAULT_PROFICIENCY_LEVEL = 'A1';
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
  const resolvedScale = (typeof scale === 'string' && scale.trim()
    ? scale.trim().toLowerCase()
    : resolveScaleForLanguage(language));
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

export function buildScaleLevelState({ level, language = null, scale = null } = {}) {
  const profile = getProficiencyProfile({ language, scale });
  const normalizedLevel = normalizeDifficultyLevel(level, { language, scale: profile.scale })
    ?? profile.defaultLevel;
  return {
    scale: profile.scale,
    level: normalizedLevel,
    level_index: profile.levels.indexOf(normalizedLevel)
  };
}

function normalizeRequiredLevel(level, profile) {
  const normalized = normalizeDifficultyLevel(level, { scale: profile.scale });
  if (!normalized) {
    throw new InvalidProficiencyLevelError(level, profile.scale);
  }
  return normalized;
}