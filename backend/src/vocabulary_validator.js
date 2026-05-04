import { normalizeTerm } from './normalize.js';
import { validateDifficultyLevel } from './proficiency.js';

const requiredFields = [
  'term',
  'language',
  'meaning_vi',
  'ipa',
  'vietnamese_pronunciation',
  'example',
  'example_vi',
  'difficulty',
  'topics'
];

export function validateVocabularyItem(item) {
  for (const field of requiredFields) {
    if (item[field] === undefined || item[field] === null || item[field] === '') {
      return { ok: false, reason: `missing_${field}` };
    }
  }
  if (!Array.isArray(item.topics)) {
    return { ok: false, reason: 'topics_must_be_array' };
  }
  if (!String(item.ipa).trim()) {
    return { ok: false, reason: 'empty_ipa' };
  }
  if (!validateDifficultyLevel(item.difficulty)) {
    return { ok: false, reason: 'invalid_difficulty' };
  }
  const normalizedTerm = normalizeTerm(item.term);
  const normalizedExample = normalizeTerm(item.example);
  if (!normalizedExample.includes(normalizedTerm)) {
    return { ok: false, reason: 'example_unrelated_to_term' };
  }
  return { ok: true };
}
