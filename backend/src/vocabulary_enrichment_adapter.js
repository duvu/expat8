import { validateVocabularyItem } from './vocabulary_validator.js';

export class VocabularyEnrichmentAdapter {
  constructor({ liteLLMClient = null, logger = console, sourceLanguage = 'vi' } = {}) {
    this.liteLLMClient = liteLLMClient;
    this.logger = logger;
    this.sourceLanguage = sourceLanguage;
  }

  async enrichTerm({ term, language = 'en', context = '', frequency = 1, confidence = 0.5 }) {
    let candidate = null;

    if (this.liteLLMClient) {
      const aiResult = await this.#enrichWithAI({ term, language, context });
      if (!aiResult.ok) {
        return aiResult;
      }
      candidate = aiResult.item;
    } else {
      candidate = this.#fallbackItem({ term, language, context });
    }

    const item = {
      ...candidate,
      term,
      language,
      frequency,
      confidence,
      quality_score: Number((candidate.quality_score ?? confidence).toFixed(2))
    };

    const validation = validateVocabularyItem(item);
    if (!validation.ok) {
      return {
        ok: false,
        classification: 'invalid_schema',
        reason: validation.reason,
        term
      };
    }

    return {
      ok: true,
      item
    };
  }

  async #enrichWithAI({ term, language, context }) {
    try {
      const content = await this.liteLLMClient.generateVocabulary({
        sourceLanguage: this.sourceLanguage,
        targetLanguage: language,
        limit: 1,
        avoidTerms: [],
        difficultyLevel: 'A1'
      });
      const parsed = parseFirstItem(content);
      if (!parsed) {
        return {
          ok: false,
          classification: 'malformed_json',
          reason: 'invalid_ai_output_json',
          term
        };
      }
      return {
        ok: true,
        item: {
          ...parsed,
          short_definition: parsed.short_definition ?? null,
          quality_score: Number(parsed.confidence ?? 0.7),
          example: parsed.example ?? context ?? `${term} appears in the uploaded article.`
        }
      };
    } catch (error) {
      this.logger.warn?.('article_enrichment_failed', { term, error });
      return {
        ok: false,
        classification: 'ai_request_failed',
        reason: `${error}`,
        term
      };
    }
  }

  #fallbackItem({ term, language, context }) {
    return {
      term,
      language,
      meaning_vi: `Nghia cua ${term}`,
      part_of_speech: 'unknown',
      ipa: '/na/',
      vietnamese_pronunciation: term,
      example: context || `${term} appears in the uploaded article.`,
      example_vi: `${term} xuat hien trong bai viet duoc tai len.`,
      difficulty: 'A1',
      topics: ['article-ingestion'],
      level_scale: 'cefr',
      quality_score: 0.5
    };
  }
}

function parseFirstItem(raw) {
  try {
    const text = String(raw ?? '').trim().replace(/^```(?:json)?/i, '').replace(/```$/i, '').trim();
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed)) {
      return parsed[0] ?? null;
    }
    if (Array.isArray(parsed.items)) {
      return parsed.items[0] ?? null;
    }
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch {
    return null;
  }
}
