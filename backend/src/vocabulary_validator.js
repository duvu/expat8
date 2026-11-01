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
  const language = String(item.language ?? '')
    .trim()
    .toLowerCase();
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

// Pinyin: ASCII letters plus the tone-marked vowels (and ü/ê), syllables separated by spaces, apostrophes
// or hyphens. Vietnamese letters (ư ơ ă â ô ế ạ ...) are deliberately outside this set, so a Hán-Việt
// reading ("cửu tuần") is not mistaken for pinyin.
const PINYIN = /^[a-zA-ZüÜêÊāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ\s'’·-]+$/u;

function hasPinyin(value) {
  return PINYIN.test(value.trim());
}

export function normalizeSuggestionType(value, term) {
  const trimmed = String(value ?? '')
    .trim()
    .toLowerCase();
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
