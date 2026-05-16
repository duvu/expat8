import assert from 'node:assert/strict';
import test from 'node:test';

import { WordStore } from '../src/word_store.js';
import { ArticleProcessingPipeline } from '../src/article_processing_pipeline.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeSuggestionAdapter(suggestions = []) {
  const calls = [];
  return {
    calls,
    suggestVocabulary({ chunk, chunkIndex }) {
      calls.push({ chunk, chunkIndex });
      return suggestions.map((s) => ({ ...s }));
    }
  };
}

function makeWordSuggestion(overrides = {}) {
  return {
    term: 'benchmark',
    language: 'en',
    meaning_vi: 'tieu chuan',
    part_of_speech: 'noun',
    ipa: '/ˈbentʃmɑːrk/',
    vietnamese_pronunciation: 'bench-mark',
    example: 'Set a benchmark for performance.',
    example_vi: 'Dat tieu chuan cho hieu suat.',
    difficulty: 'B1',
    level: 'B1',
    topics: ['technology'],
    classification: 'article_keyword',
    suggestion_type: 'word',
    frequency: 2,
    confidence: 0.85,
    ...overrides
  };
}

function makePhraseSuggestion(overrides = {}) {
  return {
    term: 'set a benchmark',
    language: 'en',
    meaning_vi: 'dat tieu chuan',
    part_of_speech: 'verb phrase',
    ipa: '/set ə ˈbentʃmɑːrk/',
    vietnamese_pronunciation: 'set a bench-mark',
    example: 'Teams set a benchmark for success.',
    example_vi: 'Cac doi dat tieu chuan cho thanh cong.',
    difficulty: 'B1',
    level: 'B1',
    topics: ['business'],
    classification: 'article_phrase',
    suggestion_type: 'phrase',
    frequency: 1,
    confidence: 0.9,
    ...overrides
  };
}

function makeSentenceSuggestion(overrides = {}) {
  return {
    text: 'Could we move this meeting to tomorrow morning?',
    language: 'en',
    meaning_vi: 'Chung ta co the chuyen cuoc hop nay sang sang mai duoc khong?',
    topic: 'meetings',
    ...overrides
  };
}

// ---------------------------------------------------------------------------
// Task 4.1 — chunking behaviour
// ---------------------------------------------------------------------------

test('short article (below maxChunkChars) produces a single chunk and calls adapter once', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'u1',
    title: 'Short article',
    language: 'en',
    rawText: 'Short text. Just one chunk.'
  });

  const adapter = makeSuggestionAdapter([makeWordSuggestion()]);
  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: adapter,
    maxChunkChars: 1800
  });

  await pipeline.processArticle({ articleId: article.id });

  assert.equal(adapter.calls.length, 1, 'adapter should be called exactly once for a short article');
  assert.equal(adapter.calls[0].chunkIndex, 0, 'first (and only) chunk index is 0');
});

test('long article (above maxChunkChars) is split into multiple chunks and adapter called per chunk', async () => {
  const store = new WordStore({ seed: false });
  // Build text that guarantees two chunks when maxChunkChars = 100:
  // Two paragraphs of 80 chars each → each paragraph is one chunk
  const paragraph1 = 'A'.repeat(80);
  const paragraph2 = 'B'.repeat(80);
  const article = store.createArticle({
    userId: 'u2',
    title: 'Long article',
    language: 'en',
    rawText: `${paragraph1}\n\n${paragraph2}`
  });

  const adapter = makeSuggestionAdapter([]); // no suggestions needed — just count calls
  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: adapter,
    maxChunkChars: 100
  });

  await pipeline.processArticle({ articleId: article.id });

  assert.ok(adapter.calls.length >= 2, 'adapter should be called at least twice for a long article');
  // chunk indices should be sequential starting from 0
  const indices = adapter.calls.map((c) => c.chunkIndex);
  assert.deepEqual(indices, Array.from({ length: adapter.calls.length }, (_, i) => i));
});

test('extremely long single paragraph is split by character boundary', async () => {
  const store = new WordStore({ seed: false });
  const longParagraph = 'word '.repeat(500); // ~2500 chars, no newlines
  const article = store.createArticle({
    userId: 'u3',
    title: 'One big paragraph',
    language: 'en',
    rawText: longParagraph
  });

  const adapter = makeSuggestionAdapter([]);
  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: adapter,
    maxChunkChars: 200
  });

  await pipeline.processArticle({ articleId: article.id });

  assert.ok(adapter.calls.length >= 2, 'character-split should produce multiple chunks');
});

// ---------------------------------------------------------------------------
// Task 4.2 — phrase suggestions, classification, and level metadata
// ---------------------------------------------------------------------------

test('phrase suggestion flows through pipeline and is persisted with suggestion_type phrase', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'u4',
    title: 'Phrase article',
    language: 'en',
    rawText: 'Teams set a benchmark for success in every project.'
  });

  const adapter = makeSuggestionAdapter([makePhraseSuggestion()]);
  const pipeline = new ArticleProcessingPipeline({ store, suggestionAdapter: adapter });

  const result = await pipeline.processArticle({ articleId: article.id });

  assert.equal(result.accepted_count, 1, 'phrase should be accepted');
  const persisted = [...store.articleTermsById.values()];
  assert.equal(persisted.length, 1);
  assert.equal(persisted[0].suggestion_type, 'phrase');
  assert.equal(persisted[0].classification, 'article_phrase');
});

test('word suggestion is persisted with correct classification and level', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'u5',
    title: 'Word article',
    language: 'en',
    rawText: 'Performance benchmark helps teams measure progress.'
  });

  const adapter = makeSuggestionAdapter([makeWordSuggestion()]);
  const pipeline = new ArticleProcessingPipeline({ store, suggestionAdapter: adapter });

  await pipeline.processArticle({ articleId: article.id });

  const persisted = [...store.articleTermsById.values()];
  assert.equal(persisted.length, 1);
  assert.equal(persisted[0].classification, 'article_keyword');
  assert.equal(persisted[0].suggestion_type, 'word');

  // Verify level is persisted in word_sense
  const sense = [...store.wordSensesById.values()][0];
  assert.equal(sense.level, 'B1');
});

test('multiple suggestions across chunks are deduplicated by normalized term', async () => {
  const store = new WordStore({ seed: false });
  const para1 = 'The benchmark matters.';
  const para2 = 'Use a benchmark for comparison.';
  const article = store.createArticle({
    userId: 'u6',
    title: 'Dedup article',
    language: 'en',
    rawText: `${para1}\n\n${para2}`
  });

  // Both chunks return a suggestion for the same term "benchmark"
  const adapter = {
    suggestVocabulary() {
      return [makeWordSuggestion()];
    }
  };
  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: adapter,
    maxChunkChars: 50
  });

  const result = await pipeline.processArticle({ articleId: article.id });

  // Only 1 unique term should be persisted despite duplicate suggestions across chunks
  assert.equal(store.articleTermsById.size, 1, 'duplicate terms across chunks should be deduplicated');
  assert.equal(result.accepted_count, 1);
});

test('article_vocabulary read exposes classification and suggestion_type', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'user_vocab_test',
    title: 'Vocab test',
    language: 'en',
    rawText: 'Set a benchmark for the team.'
  });

  const adapter = makeSuggestionAdapter([makePhraseSuggestion()]);
  const pipeline = new ArticleProcessingPipeline({ store, suggestionAdapter: adapter });
  await pipeline.processArticle({ articleId: article.id });

  const vocabulary = store.getArticleVocabulary({
    articleId: article.id,
    userId: article.owner_user_id
  });
  assert.ok(vocabulary, 'vocabulary should be returned');
  assert.equal(vocabulary.items.length, 1);
  const item = vocabulary.items[0];
  assert.equal(item.classification, 'article_phrase');
  assert.equal(item.suggestion_type, 'phrase');
  assert.equal(item.level, 'B1');
});

test('pipeline persists workplace sentence candidates for later feed serving', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'user_sentence_pipeline',
    title: 'Meeting coordination',
    language: 'en',
    rawText: 'Could we move this meeting to tomorrow morning?'
  });

  const adapter = {
    suggestVocabulary() {
      return [];
    },
    suggestWorkplaceSentences() {
      return [makeSentenceSuggestion()];
    }
  };
  const pipeline = new ArticleProcessingPipeline({ store, suggestionAdapter: adapter });

  const result = await pipeline.processArticle({ articleId: article.id });

  assert.equal(result.sentence_accepted_count, 1);
  assert.equal(store.workplaceSentencesById.size, 1);
  const persisted = [...store.workplaceSentencesById.values()][0];
  assert.equal(persisted.text, 'Could we move this meeting to tomorrow morning?');
  assert.equal(persisted.topic, 'meetings');
});

test('missing suggestion adapter returns adapter_missing classification in result', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'u7',
    title: 'No adapter',
    language: 'en',
    rawText: 'Some article text here.'
  });

  const pipeline = new ArticleProcessingPipeline({ store });

  const result = await pipeline.processArticle({ articleId: article.id });

  assert.equal(result.accepted_count, 0);
  assert.ok(result.rejected.some((r) => r.classification === 'article_suggestion_adapter_missing'));
});
