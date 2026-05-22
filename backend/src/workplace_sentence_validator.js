import { normalizeTerm } from './normalize.js';

const MAX_SENTENCE_LENGTH = 240;
const MIN_WORD_COUNT = 3;

export function normalizeSentenceText(text) {
  return String(text ?? '')
    .trim()
    .toLocaleLowerCase('en-US')
    .replace(/[^\p{L}\p{N}\s']/gu, ' ')
    .replace(/\s+/g, ' ');
}

export function validateWorkplaceSentenceItem(item) {
  const text = String(item.text ?? '').trim();
  const language = String(item.language ?? '')
    .trim()
    .toLowerCase();
  const meaningVi = String(item.meaning_vi ?? '').trim();

  if (!text) {
    return { ok: false, reason: 'missing_text' };
  }
  if (!language) {
    return { ok: false, reason: 'missing_language' };
  }
  if (!meaningVi) {
    return { ok: false, reason: 'missing_meaning_vi' };
  }
  if (text.length > MAX_SENTENCE_LENGTH) {
    return { ok: false, reason: 'sentence_too_long' };
  }

  const normalized = normalizeSentenceText(text);
  if (!normalized) {
    return { ok: false, reason: 'invalid_text' };
  }

  const wordCount = normalized.split(' ').filter(Boolean).length;
  if (wordCount < MIN_WORD_COUNT) {
    return { ok: false, reason: 'sentence_too_short' };
  }

  if (language !== 'en') {
    return { ok: false, reason: 'unsupported_language' };
  }

  if (normalizeTerm(meaningVi).length < 2) {
    return { ok: false, reason: 'invalid_meaning_vi' };
  }

  return { ok: true };
}
