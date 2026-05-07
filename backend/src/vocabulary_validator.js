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
  const language = String(item.language ?? '').trim().toLowerCase();
  if (!String(item.ipa).trim() && !language.startsWith('zh')) {
    return { ok: false, reason: 'empty_ipa' };
  }
  if (!validateDifficultyLevel(item.difficulty, { language: item.language })) {
    return { ok: false, reason: 'invalid_difficulty' };
  }
  if (language.startsWith('zh') && !/[a-zA-Z]/.test(String(item.vietnamese_pronunciation))) {
    return { ok: false, reason: 'invalid_chinese_pronunciation' };
  }
  const normalizedTerm = normalizeTerm(item.term);
  const normalizedExample = normalizeTerm(item.example);
  if (!normalizedExample.includes(normalizedTerm) && !language.startsWith('zh')) {
    return { ok: false, reason: 'example_unrelated_to_term' };
  }
  return { ok: true };
}
