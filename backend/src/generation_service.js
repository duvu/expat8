import { normalizeTerm } from './normalize.js';
import { normalizeDifficultyLevel } from './proficiency.js';
import { validateVocabularyItem } from './vocabulary_validator.js';

export class VocabularyGenerationService {
  constructor({ liteLLMClient, store, logger = console }) {
    this.liteLLMClient = liteLLMClient;
    this.store = store;
    this.logger = logger;
  }

  async generateAndStore({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    limit = 5,
    avoidTerms = [],
    difficultyLevel = 'B1'
  }) {
    const accepted = [];
    const blockedTerms = new Set(
      avoidTerms.map((term) => normalizeTerm(String(term)))
    );

    for (let attempt = 0; attempt < 3 && accepted.length < limit; attempt += 1) {
      let raw;
      try {
        raw = await this.liteLLMClient.generateVocabulary({
          sourceLanguage,
          targetLanguage,
          limit: limit - accepted.length,
          avoidTerms: [...blockedTerms],
          difficultyLevel
        });
      } catch (error) {
        this.logger.warn('ai_generation_failed', { reason: error.message });
        break;
      }

      const items = parseVocabularyJson(raw);
      for (const item of items) {
        const candidate = {
          ...item,
          language: item.language ?? targetLanguage,
          difficulty: normalizeDifficultyLevel(item.difficulty) ?? item.difficulty,
          generation_source: 'litellm'
        };
        const normalizedCandidateTerm = normalizeTerm(String(candidate.term ?? ''));
        blockedTerms.add(normalizedCandidateTerm);
        const validation = validateVocabularyItem(candidate);
        if (!validation.ok) {
          this.logger.warn('ai_generation_item_rejected', { reason: validation.reason });
          continue;
        }
        const { word, inserted } = await this.store.insertWord(candidate);
        if (inserted) {
          accepted.push(word);
        }
      }
    }

    return accepted;
  }
}

export function parseVocabularyJson(raw) {
  try {
    const parsed = JSON.parse(extractJson(raw));
    if (Array.isArray(parsed)) {
      return parsed;
    }
    if (Array.isArray(parsed.items)) {
      return parsed.items;
    }
    return [];
  } catch {
    return [];
  }
}

function extractJson(raw) {
  const trimmed = String(raw).trim();
  if (trimmed.startsWith('```')) {
    return trimmed.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  }
  return trimmed;
}
