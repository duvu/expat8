import { normalizeTerm } from './normalize.js';
import { normalizeDifficultyLevel } from './proficiency.js';
import { normalizeSuggestionType, validateVocabularyItem } from './vocabulary_validator.js';
import { normalizeSentenceText, validateWorkplaceSentenceItem } from './workplace_sentence_validator.js';

const DEFAULT_MAX_CHUNK_CHARS = 1800;
const DEFAULT_MAX_SUGGESTIONS_PER_CHUNK = 10;

export class ArticleProcessingPipeline {
  constructor({
    store,
    suggestionAdapter = null,
    logger = console,
    maxChunkChars = DEFAULT_MAX_CHUNK_CHARS,
    maxSuggestionsPerChunk = DEFAULT_MAX_SUGGESTIONS_PER_CHUNK
  }) {
    this.store = store;
    this.suggestionAdapter = suggestionAdapter;
    this.logger = logger;
    this.maxChunkChars = Math.max(1, maxChunkChars);
    this.maxSuggestionsPerChunk = Math.max(1, maxSuggestionsPerChunk);
  }

  async processArticle({ articleId, maxTerms = this.maxSuggestionsPerChunk }) {
    const article = await this.store.getArticleById({ articleId });
    if (!article) {
      return {
        success: false,
        classification: 'article_not_found',
        extracted_count: 0,
        accepted_count: 0,
        rejected_count: 0
      };
    }

    const text = String(article.cleaned_text ?? article.raw_text ?? '');
    const chunks = chunkArticleText(text, { maxChars: this.maxChunkChars });
    const extracted = [];
    const accepted = [];
    const rejected = [];
    const seen = new Set();
    const extractedSentences = [];
    const acceptedSentences = [];
    const rejectedSentences = [];
    const seenSentences = new Set();

    for (let chunkIndex = 0; chunkIndex < chunks.length; chunkIndex += 1) {
      const chunk = chunks[chunkIndex];
      const suggestionResult = await this.#suggestForChunk({
        article,
        chunk,
        chunkIndex,
        maxSuggestions: Math.max(1, Math.min(this.maxSuggestionsPerChunk, maxTerms))
      });

      if (!suggestionResult.ok) {
        rejected.push({
          term: null,
          classification: suggestionResult.classification,
          reason: suggestionResult.reason,
          chunk_index: chunkIndex
        });
        continue;
      }

      for (const suggestion of suggestionResult.items) {
        extracted.push(suggestion);

        const normalizedTerm = normalizeTerm(String(suggestion.term ?? ''));
        if (!normalizedTerm || seen.has(`${article.language}:${normalizedTerm}`)) {
          rejected.push({
            term: suggestion.term,
            classification: 'duplicate_suggestion',
            reason: 'duplicate_across_chunks'
          });
          continue;
        }

        const candidate = {
          ...suggestion,
          language: suggestion.language ?? article.language,
          difficulty:
            normalizeDifficultyLevel(suggestion.difficulty ?? suggestion.level, {
              language: suggestion.language ?? article.language
            }) ??
            suggestion.difficulty ??
            suggestion.level,
          level: suggestion.level ?? suggestion.difficulty ?? null,
          suggestion_type: normalizeSuggestionType(suggestion.suggestion_type, suggestion.term),
          frequency: suggestion.frequency ?? 1,
          confidence: suggestion.confidence ?? suggestion.quality_score ?? 0.5,
          article_chunk_index: chunkIndex,
          article_chunk_text: chunk
        };

        const validation = validateVocabularyItem(candidate, { requireSuggestionMetadata: true });
        if (!validation.ok) {
          rejected.push({
            term: suggestion.term,
            classification: validation.reason,
            reason: validation.reason
          });
          continue;
        }

        seen.add(`${article.language}:${normalizedTerm}`);
        accepted.push(candidate);
      }

      const sentenceResult = await this.#suggestSentencesForChunk({
        article,
        chunk,
        chunkIndex,
        maxSuggestions: Math.max(1, Math.min(5, maxTerms))
      });

      for (const suggestion of sentenceResult.items) {
        extractedSentences.push(suggestion);

        const normalizedText = normalizeSentenceText(suggestion.text);
        if (!normalizedText || seenSentences.has(`${article.language}:${normalizedText}`)) {
          rejectedSentences.push({
            text: suggestion.text,
            classification: 'duplicate_sentence_suggestion',
            reason: 'duplicate_across_chunks'
          });
          continue;
        }

        const candidate = {
          text: suggestion.text,
          language: suggestion.language ?? article.language,
          meaning_vi: suggestion.meaning_vi,
          topic: suggestion.topic ?? 'work',
          confidence: Number(suggestion.confidence ?? 0.5),
          generation_source: suggestion.generation_source ?? 'article_workplace_sentence',
          isStub: Boolean(suggestion.isStub)
        };

        const validation = validateWorkplaceSentenceItem(candidate);
        if (!validation.ok) {
          rejectedSentences.push({
            text: suggestion.text,
            classification: validation.reason,
            reason: validation.reason
          });
          continue;
        }

        seenSentences.add(`${article.language}:${normalizedText}`);
        acceptedSentences.push(candidate);
      }
    }

    if (accepted.length > 0) {
      await this.store.persistArticleVocabulary({ articleId, items: accepted });
    }
    if (acceptedSentences.length > 0 && typeof this.store.persistArticleWorkplaceSentences === 'function') {
      await this.store.persistArticleWorkplaceSentences({ articleId, items: acceptedSentences });
    }

    const rejectedByReason = [...rejected, ...rejectedSentences].reduce((acc, r) => {
      const key = r.classification ?? r.reason ?? 'unknown';
      acc[key] = (acc[key] ?? 0) + 1;
      return acc;
    }, {});

    this.logger.info?.('article_processing_pipeline_completed', {
      article_id: articleId,
      extracted_count: extracted.length,
      accepted_count: accepted.length,
      rejected_count: rejected.length,
      extracted_sentence_count: extractedSentences.length,
      accepted_sentence_count: acceptedSentences.length,
      rejected_sentence_count: rejectedSentences.length,
      rejected_by_reason: rejectedByReason
    });

    return {
      success: true,
      classification: rejected.length > 0 || rejectedSentences.length > 0 ? 'partial_success' : 'success',
      extracted_count: extracted.length + extractedSentences.length,
      accepted_count: accepted.length + acceptedSentences.length,
      rejected_count: rejected.length + rejectedSentences.length,
      rejected: [...rejected, ...rejectedSentences],
      vocabulary_accepted_count: accepted.length,
      sentence_accepted_count: acceptedSentences.length
    };
  }

  async #suggestForChunk({ article, chunk, chunkIndex, maxSuggestions }) {
    if (this.suggestionAdapter?.suggestVocabulary) {
      const result = await this.suggestionAdapter.suggestVocabulary({
        article,
        chunk,
        chunkIndex,
        maxSuggestions
      });
      if (Array.isArray(result)) {
        return { ok: true, items: result };
      }
      return result;
    }

    return {
      ok: false,
      classification: 'article_suggestion_adapter_missing',
      reason: 'article_suggestion_adapter_missing'
    };
  }

  async #suggestSentencesForChunk({ article, chunk, chunkIndex, maxSuggestions }) {
    if (this.suggestionAdapter?.suggestWorkplaceSentences) {
      const result = await this.suggestionAdapter.suggestWorkplaceSentences({
        article,
        chunk,
        chunkIndex,
        maxSuggestions
      });
      if (Array.isArray(result)) {
        return { ok: true, items: result };
      }
      if (result?.ok === false) {
        return { ok: true, items: [] };
      }
      return result ?? { ok: true, items: [] };
    }

    return { ok: true, items: [] };
  }
}

function chunkArticleText(text, { maxChars }) {
  const cleaned = String(text ?? '').trim();
  if (!cleaned) {
    return [''];
  }

  const paragraphs = cleaned
    .split(/\n{2,}/)
    .map((part) => part.trim())
    .filter(Boolean);

  const chunks = [];
  let current = '';

  const flush = () => {
    if (current.trim()) {
      chunks.push(current.trim());
      current = '';
    }
  };

  for (const paragraph of paragraphs.length > 0 ? paragraphs : [cleaned]) {
    if (paragraph.length > maxChars) {
      flush();
      chunks.push(...splitLongParagraph(paragraph, maxChars));
      continue;
    }

    if (!current) {
      current = paragraph;
      continue;
    }

    if (current.length + 2 + paragraph.length <= maxChars) {
      current = `${current}\n\n${paragraph}`;
      continue;
    }

    flush();
    current = paragraph;
  }

  flush();
  return chunks.length > 0 ? chunks : [cleaned.slice(0, maxChars)];
}

function splitLongParagraph(paragraph, maxChars) {
  const sentences = paragraph
    .split(/(?<=[.!?。！？])\s+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);

  if (sentences.length === 0) {
    return splitByLength(paragraph, maxChars);
  }

  const chunks = [];
  let current = '';

  for (const sentence of sentences) {
    if (sentence.length > maxChars) {
      if (current) {
        chunks.push(current.trim());
        current = '';
      }
      chunks.push(...splitByLength(sentence, maxChars));
      continue;
    }

    if (!current) {
      current = sentence;
      continue;
    }

    if (current.length + 1 + sentence.length <= maxChars) {
      current = `${current} ${sentence}`;
      continue;
    }

    chunks.push(current.trim());
    current = sentence;
  }

  if (current.trim()) {
    chunks.push(current.trim());
  }

  return chunks;
}

function splitByLength(text, maxChars) {
  const chunks = [];
  let index = 0;
  while (index < text.length) {
    chunks.push(text.slice(index, index + maxChars).trim());
    index += maxChars;
  }
  return chunks.filter(Boolean);
}
