import { normalizeTerm } from './normalize.js';
import { validateDifficultyLevel } from './proficiency.js';

const requiredFields = [
  'term',
  'language',
  'meaning_vi',
  'vietnamese_pronunciation',
  'example',
  'example_vi',
  'topics'
];

export function validateVocabularyItem(item, options = {}) {
  const language = String(item.language ?? '').trim().toLowerCase();
  const isChinese = language.startsWith('zh');
  const difficulty = item.difficulty ?? item.level;
  const suggestionType = normalizeSuggestionType(item.suggestion_type, item.term);
  const requireSuggestionMetadata = Boolean(options.requireSuggestionMetadata);

  for (const field of requiredFields) {
    if (item[field] === undefined || item[field] === null || item[field] === '') {
      return { ok: false, reason: `missing_${field}` };
    }
  }
  if (!isChinese && !String(item.ipa ?? '').trim()) {
    return { ok: false, reason: 'missing_ipa' };
  }
  if (isChinese && !hasPinyin(String(item.vietnamese_pronunciation ?? ''))) {
    return { ok: false, reason: 'invalid_chinese_pinyin' };
  }
  if (!Array.isArray(item.topics)) {
    return { ok: false, reason: 'topics_must_be_array' };
  }
  if (!validateDifficultyLevel(difficulty, { language: item.language })) {
    return { ok: false, reason: 'invalid_difficulty' };
  }
  if (requireSuggestionMetadata && !String(item.classification ?? '').trim()) {
    return { ok: false, reason: 'missing_classification' };
  }
  if (requireSuggestionMetadata && !suggestionType) {
    return { ok: false, reason: 'missing_suggestion_type' };
  }
  const normalizedTerm = normalizeTerm(item.term);
  const normalizedExample = normalizeTerm(item.example);
  if (!normalizedExample.includes(normalizedTerm) && !isChinese) {
    return { ok: false, reason: 'example_unrelated_to_term' };
  }
  return { ok: true };
}

function hasPinyin(value) {
  const pronunciation = value.trim();
  return /[a-zA-Z]/.test(pronunciation);
}

export function normalizeSuggestionType(value, term) {
  const trimmed = String(value ?? '').trim().toLowerCase();
  if (trimmed) {
    if (trimmed === 'multiword') {
      return 'phrase';
    }
    if (trimmed === 'word' || trimmed === 'phrase') {
      return trimmed;
    }
    return null;
  }

  const normalizedTerm = normalizeTerm(String(term ?? ''));
  if (!normalizedTerm) {
    return null;
  }
  return normalizedTerm.includes(' ') ? 'phrase' : 'word';
}
