import { normalizeTerm } from './normalize.js';
import { normalizeDifficultyLevel } from './proficiency.js';
import { normalizeSuggestionType, validateVocabularyItem } from './vocabulary_validator.js';

const MAX_SEGMENTS = 50;

const SEGMENTATION_SYSTEM_PROMPT = `You are a text segmentation expert. Your task is to divide a passage into memorizable chunks for language learners.

Each chunk should:
- Contain 3-5 sentences (50-150 words)
- Be a self-contained meaning unit
- Respect rhetorical structure (keep parallelism, repetition, and climax together)
- End at natural pause points

Return a JSON array of segments, each with "text" containing the exact text of that segment.
Do NOT modify the original text. Each character of the input must appear in exactly one segment.

Example output format:
[
  {"text": "First segment text here. It continues naturally."},
  {"text": "Second segment begins here. More sentences follow. And another."}
]`;

export class PassageSegmentationPipeline {
  constructor({ store, liteLLMClient, suggestionAdapter = null, logger = console, maxSuggestionsPerSegment = 10 }) {
    this.store = store;
    this.liteLLMClient = liteLLMClient;
    this.suggestionAdapter = suggestionAdapter;
    this.logger = logger;
    this.maxSuggestionsPerSegment = Math.max(1, maxSuggestionsPerSegment);
  }

  async processPassage({ passageId }) {
    const passage = await this.store.getPassage({ passageId });
    if (!passage) {
      return { success: false, error: 'passage_not_found' };
    }

    const text = passage.raw_text;
    const language = passage.language;

    try {
      const segments = await this.#segment({ text, language });

      if (segments.length === 0) {
        return { success: false, error: 'no_segments_produced' };
      }

      // Cap at MAX_SEGMENTS
      const capped = segments.slice(0, MAX_SEGMENTS);
      if (segments.length > MAX_SEGMENTS) {
        this.logger.warn?.('passage_segmentation_capped', {
          passage_id: passageId,
          produced: segments.length,
          capped_to: MAX_SEGMENTS
        });
      }

      // Create segment records
      const segmentInputs = capped.map((seg, idx) => ({
        position: idx,
        text: seg.text
      }));

      const created = await this.store.createSegments({ passageId, segments: segmentInputs });
      const vocabulary = await this.#extractVocabulary({ passage, segments: created });

      // Update passage status
      await this.store.updatePassage({
        passageId,
        status: 'segmented',
        segment_count: created.length
      });

      this.logger.info?.('passage_segmentation_completed', {
        passage_id: passageId,
        segment_count: created.length,
        vocabulary_count: vocabulary.count
      });

      return { success: true, segment_count: created.length, vocabulary_count: vocabulary.count };
    } catch (error) {
      this.logger.error?.('passage_segmentation_failed', {
        passage_id: passageId,
        error
      });
      return { success: false, error: `${error}` };
    }
  }

  async #segment({ text, language }) {
    const userPrompt = `Segment the following ${language.toUpperCase()} passage into memorizable chunks (3-5 sentences each, 50-150 words each). Respect rhetorical structure and natural pause points.\n\nPassage:\n${text}`;

    const response = await this.liteLLMClient.chatCompletion({
      messages: [
        { role: 'system', content: SEGMENTATION_SYSTEM_PROMPT },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.3,
      response_format: { type: 'json_object' }
    });

    const content = response?.choices?.[0]?.message?.content;
    if (!content) {
      throw new Error('Empty LLM response for segmentation');
    }

    const parsed = JSON.parse(content);
    // Accept both { segments: [...] } and direct array
    const rawSegments = Array.isArray(parsed) ? parsed : (parsed.segments ?? []);

    // Normalize: LLM may return plain strings or objects with `text` field
    const segments = rawSegments.map((s) => {
      if (typeof s === 'string') return { text: s };
      if (s && typeof s.text === 'string') return s;
      return null;
    });

    // Validate each segment has non-empty text
    const valid = segments.filter(
      (s) => s && typeof s.text === 'string' && s.text.trim().length > 0
    );

    return valid;
  }

  async #extractVocabulary({ passage, segments }) {
    if (!this.suggestionAdapter?.suggestVocabulary || typeof this.store.persistPassageVocabulary !== 'function') {
      return { count: 0 };
    }

    const accepted = [];
    const seen = new Set();
    const articleLikePassage = {
      id: passage.id,
      title: passage.title,
      language: passage.language
    };

    for (let index = 0; index < segments.length; index += 1) {
      const segment = segments[index];
      const result = await this.suggestionAdapter.suggestVocabulary({
        article: articleLikePassage,
        chunk: segment.text,
        chunkIndex: index,
        maxSuggestions: this.maxSuggestionsPerSegment
      });
      const items = Array.isArray(result) ? result : result?.items ?? [];

      for (const suggestion of items) {
        const normalizedTerm = normalizeTerm(String(suggestion.term ?? ''));
        const language = suggestion.language ?? passage.language;
        const dedupeKey = `${segment.id}:${language}:${normalizedTerm}`;
        if (!normalizedTerm || seen.has(dedupeKey)) {
          continue;
        }

        const candidate = {
          ...suggestion,
          segment_id: segment.id,
          language,
          difficulty:
            normalizeDifficultyLevel(suggestion.difficulty ?? suggestion.level, { language }) ??
            suggestion.difficulty ??
            suggestion.level,
          level: suggestion.level ?? suggestion.difficulty ?? null,
          suggestion_type: normalizeSuggestionType(suggestion.suggestion_type, suggestion.term),
          frequency: suggestion.frequency ?? 1,
          confidence: suggestion.confidence ?? suggestion.quality_score ?? 0.5,
          article_chunk_index: index,
          article_chunk_text: segment.text
        };
        const validation = validateVocabularyItem(candidate, { requireSuggestionMetadata: true });
        if (!validation.ok) {
          continue;
        }

        seen.add(dedupeKey);
        accepted.push(candidate);
      }
    }

    if (accepted.length === 0) {
      return { count: 0 };
    }
    return this.store.persistPassageVocabulary({ passageId: passage.id, items: accepted });
  }
}
