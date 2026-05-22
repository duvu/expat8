import { normalizeTerm } from './normalize.js';

const DEFAULT_STOPWORDS = new Set([
  'the',
  'and',
  'for',
  'with',
  'from',
  'that',
  'this',
  'have',
  'has',
  'had',
  'are',
  'was',
  'were',
  'will',
  'would',
  'about',
  'into',
  'your',
  'their',
  'them',
  'then',
  'than',
  'when',
  'where',
  'which',
  'while',
  'after',
  'before'
]);

export function extractCandidateTerms({ text, maxTerms = 20, language = 'en' }) {
  const cleaned = String(text ?? '').toLowerCase();
  const tokens = cleaned
    .replace(/[^\p{L}\p{N}\s']/gu, ' ')
    .split(/\s+/)
    .map((token) => token.trim())
    .filter((token) => token.length >= 3);

  const counts = new Map();
  for (const token of tokens) {
    if (DEFAULT_STOPWORDS.has(token)) {
      continue;
    }
    const normalized = normalizeTerm(token);
    if (!normalized) {
      continue;
    }
    counts.set(normalized, (counts.get(normalized) ?? 0) + 1);
  }

  return [...counts.entries()]
    .sort((left, right) => right[1] - left[1])
    .slice(0, Math.max(1, Math.min(maxTerms, 200)))
    .map(([term, frequency]) => ({
      term,
      language,
      frequency,
      confidence: estimateExtractionConfidence({ frequency })
    }));
}

function estimateExtractionConfidence({ frequency }) {
  const capped = Math.max(1, Math.min(frequency, 5));
  return Number((0.4 + capped * 0.1).toFixed(2));
}
