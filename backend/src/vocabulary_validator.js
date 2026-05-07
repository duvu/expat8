import { normalizeTerm } from './normalize.js';
import { validateDifficultyLevel } from './proficiency.js';

const requiredFields = [
  'term',
  'language',
  'meaning_vi',
  'vietnamese_pronunciation',
  'example',
  'example_vi',
  'difficulty',
  'topics'
];

export function validateVocabularyItem(item) {
  const language = String(item.language ?? '').trim().toLowerCase();
  const isChinese = language.startsWith('zh');

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
  if (!validateDifficultyLevel(item.difficulty, { language: item.language })) {
    return { ok: false, reason: 'invalid_difficulty' };
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
