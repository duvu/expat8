import { validateVocabularyItem } from './vocabulary_validator.js';

export class VocabularyGenerationService {
  constructor({ liteLLMClient, store, logger = console }) {
    this.liteLLMClient = liteLLMClient;
    this.store = store;
    this.logger = logger;
  }

  async generateAndStore({ sourceLanguage = 'vi', targetLanguage = 'en', limit = 5 }) {
    let raw;
    try {
      raw = await this.liteLLMClient.generateVocabulary({
        sourceLanguage,
        targetLanguage,
        limit
      });
    } catch (error) {
      this.logger.warn('ai_generation_failed', { reason: error.message });
      return [];
    }

    const items = parseVocabularyJson(raw);
    const accepted = [];
    for (const item of items) {
      const candidate = {
        ...item,
        language: item.language ?? targetLanguage,
        generation_source: 'litellm'
      };
      const validation = validateVocabularyItem(candidate);
      if (!validation.ok) {
        this.logger.warn('ai_generation_item_rejected', { reason: validation.reason });
        continue;
      }
      const { word, inserted } = this.store.insertWord(candidate);
      if (inserted) {
        accepted.push(word);
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
