import { normalizeDifficultyLevel } from './proficiency.js';
import { normalizeSuggestionType } from './vocabulary_validator.js';
import { normalizeSentenceText } from './workplace_sentence_validator.js';

export class VocabularyEnrichmentAdapter {
  constructor({ liteLLMClient = null, logger = console, sourceLanguage = 'vi' } = {}) {
    this.liteLLMClient = liteLLMClient;
    this.logger = logger;
    this.sourceLanguage = sourceLanguage;
  }

  async suggestVocabulary({ article, chunk, chunkIndex = 0, maxSuggestions = 10 }) {
    if (this.liteLLMClient) {
      const aiResult = await this.#suggestWithAI({ article, chunk, chunkIndex, maxSuggestions });
      if (aiResult.ok) {
        return aiResult.items;
      }
      this.logger.warn?.('article_suggestion_failed', {
        article_id: article.id,
        chunk_index: chunkIndex,
        classification: aiResult.classification,
        reason: aiResult.reason
      });
    }

    return this.#fallbackSuggestions({ article, chunk, chunkIndex, maxSuggestions });
  }

  async suggestWorkplaceSentences({ article, chunk, chunkIndex = 0, maxSuggestions = 5 }) {
    if (article.language !== 'en') {
      return [];
    }

    if (this.liteLLMClient) {
      const aiResult = await this.#suggestWorkplaceSentencesWithAI({
        article,
        chunk,
        chunkIndex,
        maxSuggestions
      });
      if (aiResult.ok) {
        return aiResult.items;
      }
      this.logger.warn?.('article_workplace_sentence_failed', {
        article_id: article.id,
        chunk_index: chunkIndex,
        classification: aiResult.classification,
        reason: aiResult.reason
      });
    }

    return this.#fallbackWorkplaceSentences({ article, chunk, maxSuggestions });
  }

  async #suggestWithAI({ article, chunk, chunkIndex, maxSuggestions }) {
    try {
      const content = await this.liteLLMClient.generateArticleVocabularySuggestions({
        sourceLanguage: this.sourceLanguage,
        targetLanguage: article.language,
        chunk,
        chunkIndex,
        maxSuggestions,
        articleTitle: article.title,
        articleLanguage: article.language
      });
      const parsed = parseSuggestions(content);
      if (parsed.length === 0) {
        return {
          ok: false,
          classification: 'malformed_json',
          reason: 'invalid_ai_output_json'
        };
      }
      return {
        ok: true,
        items: parsed
          .slice(0, maxSuggestions)
          .map((item) => this.#normalizeSuggestion(item, { article, chunk, chunkIndex }))
          .filter((item) => item !== null)
      };
    } catch (error) {
      return {
        ok: false,
        classification: 'ai_request_failed',
        reason: `${error}`
      };
    }
  }

  async #suggestWorkplaceSentencesWithAI({ article, chunk, chunkIndex, maxSuggestions }) {
    try {
      const content = await this.liteLLMClient.generateArticleWorkplaceSentenceSuggestions({
        sourceLanguage: this.sourceLanguage,
        targetLanguage: article.language,
        chunk,
        chunkIndex,
        maxSuggestions,
        articleTitle: article.title,
        articleLanguage: article.language
      });
      const parsed = parseSuggestions(content);
      if (parsed.length === 0) {
        return {
          ok: false,
          classification: 'malformed_json',
          reason: 'invalid_ai_output_json'
        };
      }
      return {
        ok: true,
        items: parsed
          .slice(0, maxSuggestions)
          .map((item) => this.#normalizeWorkplaceSentence(item, { article }))
          .filter((item) => item !== null)
      };
    } catch (error) {
      return {
        ok: false,
        classification: 'ai_request_failed',
        reason: `${error}`
      };
    }
  }

  #fallbackSuggestions({ article, chunk, chunkIndex, maxSuggestions }) {
    const tokens = [...new Set(
      String(chunk ?? '')
        .toLowerCase()
        .replace(/[^\p{L}\p{N}\s']/gu, ' ')
        .split(/\s+/)
        .map((token) => token.trim())
        .filter((token) => token.length >= 4)
        .filter((token) => !['this', 'that', 'with', 'from', 'have', 'there', 'their', 'about'].includes(token))
    )];

    return tokens.slice(0, maxSuggestions).map((term, index) => this.#normalizeSuggestion({
      term,
      language: article.language,
      meaning_vi: `Nghia cua ${term}`,
      part_of_speech: 'unknown',
      ipa: '/na/',
      vietnamese_pronunciation: term,
      example: `This chunk mentions ${term}.`,
      example_vi: `Doan nay de cap den ${term}.`,
      difficulty: 'A1',
      topics: ['article-ingestion'],
      classification: 'fallback_suggestion',
      suggestion_type: term.includes(' ') ? 'phrase' : 'word',
      frequency: 1,
      confidence: Number((0.5 + (index * 0.05)).toFixed(2)),
      quality_score: Number((0.5 + (index * 0.05)).toFixed(2)),
      article_chunk_index: chunkIndex,
      article_chunk_text: chunk,
      isStub: true
    }, { article, chunk, chunkIndex })).filter(Boolean);
  }

  #fallbackWorkplaceSentences({ article, chunk, maxSuggestions }) {
    const sentences = String(chunk ?? '')
      .split(/(?<=[.!?])\s+/)
      .map((sentence) => sentence.trim())
      .filter((sentence) => normalizeSentenceText(sentence).split(' ').filter(Boolean).length >= 4);

    return sentences.slice(0, maxSuggestions).map((text, index) => {
      const normalized = normalizeSentenceText(text);
      if (!normalized) {
        return null;
      }
      return {
        text,
        language: article.language,
        meaning_vi: `Cau giao tiep cong viec: ${normalized}`,
        topic: 'work',
        confidence: Number((0.5 + (index * 0.05)).toFixed(2)),
        isStub: true,
        generation_source: 'article_workplace_sentence'
      };
    }).filter(Boolean);
  }

  #normalizeSuggestion(item, { article, chunk, chunkIndex }) {
    const term = String(item.term ?? '').trim();
    if (!term) {
      return null;
    }

    const language = String(item.language ?? article.language ?? '').trim() || article.language;
    const normalized = {
      ...item,
      term,
      language,
      meaning_vi: String(item.meaning_vi ?? '').trim() || `Nghia cua ${term}`,
      part_of_speech: String(item.part_of_speech ?? 'unknown').trim() || 'unknown',
      ipa: item.ipa ?? '',
      vietnamese_pronunciation: String(item.vietnamese_pronunciation ?? term).trim() || term,
      example: String(item.example ?? '').trim() || `${term} appears in the uploaded article.`,
      example_vi: String(item.example_vi ?? '').trim() || `${term} xuat hien trong bai viet duoc tai len.`,
      difficulty: normalizeDifficultyLevel(item.difficulty ?? item.level, { language }) ?? item.difficulty ?? item.level ?? 'A1',
      level: normalizeDifficultyLevel(item.level ?? item.difficulty, { language }) ?? item.level ?? item.difficulty ?? 'A1',
      topics: Array.isArray(item.topics) && item.topics.length > 0 ? item.topics : ['article-ingestion'],
      classification: String(item.classification ?? 'article_suggestion').trim() || 'article_suggestion',
      suggestion_type: normalizeSuggestionType(item.suggestion_type, term),
      frequency: Number(item.frequency ?? 1),
      confidence: Number(item.confidence ?? item.quality_score ?? 0.5),
      quality_score: Number(item.quality_score ?? item.confidence ?? 0.5),
      article_chunk_index: chunkIndex,
      article_chunk_text: chunk,
      blank_word: null
    };

    return normalized;
  }

  #normalizeWorkplaceSentence(item, { article }) {
    const text = String(item.text ?? '').trim();
    if (!text) {
      return null;
    }

    return {
      text,
      language: String(item.language ?? article.language ?? '').trim() || article.language,
      meaning_vi: String(item.meaning_vi ?? '').trim() || `Cau giao tiep cong viec: ${text}`,
      topic: String(item.topic ?? 'work').trim() || 'work',
      confidence: Number(item.confidence ?? item.quality_score ?? 0.5),
      generation_source: 'article_workplace_sentence'
    };
  }
}

function parseSuggestions(raw) {
  try {
    const text = String(raw ?? '').trim().replace(/^```(?:json)?/i, '').replace(/```$/i, '').trim();
    const parsed = JSON.parse(text);
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
