export const CEFR_LEVELS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
export const DEFAULT_PROFICIENCY_LEVEL = 'A1';
export const VALID_STUDY_RATINGS = ['easy', 'too_easy', 'hard', 'too_hard'];

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
  constructor(level) {
    super(`invalid proficiency level: ${level}`);
    this.name = 'InvalidProficiencyLevelError';
  }
}

export class InvalidStudyRatingError extends Error {
  constructor(rating) {
    super(`invalid study rating: ${rating}`);
    this.name = 'InvalidStudyRatingError';
  }
}

export function normalizeDifficultyLevel(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const trimmed = String(value).trim();
  if (!trimmed) {
    return null;
  }
  const upper = trimmed.toUpperCase();
  if (CEFR_LEVELS.includes(upper)) {
    return upper;
  }
  return LEGACY_DIFFICULTY_MAP.get(trimmed.toLowerCase()) ?? null;
}

export function validateDifficultyLevel(value) {
  return normalizeDifficultyLevel(value) !== null;
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

export function incrementLevel(level) {
  const normalized = normalizeRequiredLevel(level);
  const index = CEFR_LEVELS.indexOf(normalized);
  return CEFR_LEVELS[Math.min(index + 1, CEFR_LEVELS.length - 1)];
}

export function decrementLevel(level) {
  const normalized = normalizeRequiredLevel(level);
  const index = CEFR_LEVELS.indexOf(normalized);
  return CEFR_LEVELS[Math.max(index - 1, 0)];
}

export function getFallbackDifficultyLevels(level) {
  const normalized = normalizeRequiredLevel(level);
  const index = CEFR_LEVELS.indexOf(normalized);
  const offsets = [0, 1, -1, -2, 2, -3, 3, -4, 4, -5, 5];
  const ordered = [];

  for (const offset of offsets) {
    const candidate = CEFR_LEVELS[index + offset];
    if (candidate && !ordered.includes(candidate)) {
      ordered.push(candidate);
    }
  }

  return ordered;
}

export function isProgressionRating(rating) {
  return rating === 'too_easy' || rating === 'hard';
}

function normalizeRequiredLevel(level) {
  const normalized = normalizeDifficultyLevel(level);
  if (!normalized) {
    throw new InvalidProficiencyLevelError(level);
  }
  return normalized;
}