import assert from 'node:assert/strict';
import test from 'node:test';

import { WordStore } from '../src/word_store.js';
import { ArticleProcessingPipeline } from '../src/article_processing_pipeline.js';
import { ArticleProcessingWorker } from '../src/article_processing_worker.js';

test('worker processes queued article and persists extracted vocabulary', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'user_1',
    title: 'Learning text',
    language: 'en',
    rawText: 'Reliable teams build reliable systems and adjust plans quickly.'
  });

  const enrichmentAdapter = {
    async enrichTerm({ term, language, frequency, confidence, context }) {
      return {
        ok: true,
        item: {
          term,
          language,
          meaning_vi: `Nghia cua ${term}`,
          part_of_speech: 'noun',
          ipa: '/na/',
          vietnamese_pronunciation: term,
          example: context || `${term} in article`,
          example_vi: `${term} trong bai viet`,
          difficulty: 'A1',
          topics: ['article-ingestion'],
          frequency,
          confidence
        }
      };
    }
  };

  const pipeline = new ArticleProcessingPipeline({ store, enrichmentAdapter });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });

  const result = await worker.runOnce();

  assert.equal(result.processed, 1);
  const processedArticle = store.getArticleById({ articleId: article.id });
  assert.equal(processedArticle.status, 'processed');
  assert.ok(store.articleTermsById.size > 0);
  assert.ok(store.wordSensesById.size > 0);
});

test('worker retries then dead-letters after max attempts', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'user_2',
    title: 'Retry text',
    language: 'en',
    rawText: 'Retry behavior should eventually dead letter.'
  });

  const failingPipeline = {
    async processArticle() {
      throw new Error('pipeline_failed');
    }
  };

  const worker = new ArticleProcessingWorker({
    store,
    pipeline: failingPipeline,
    maxAttempts: 2
  });

  const first = await worker.runOnce();
  assert.equal(first.retry_scheduled, true);

  const second = await worker.runOnce();
  assert.equal(second.dead_lettered, 1);

  const currentArticle = store.getArticleById({ articleId: article.id });
  assert.equal(currentArticle.status, 'dead_lettered');
});

test('admin-created article transitions to pending_review on successful processing', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createAdminArticle({
    adminUserId: 'admin_1',
    title: 'Admin content',
    language: 'en',
    rawText: 'Admin workflow requires review before publish.'
  });

  const enrichmentAdapter = {
    async enrichTerm({ term, language, frequency, confidence }) {
      return {
        ok: true,
        item: {
          term,
          language,
          meaning_vi: `Nghia cua ${term}`,
          part_of_speech: 'noun',
          ipa: '/na/',
          vietnamese_pronunciation: term,
          example: `${term} in article`,
          example_vi: `${term} trong bai viet`,
          difficulty: 'A1',
          topics: ['article-ingestion'],
          frequency,
          confidence
        }
      };
    }
  };

  const pipeline = new ArticleProcessingPipeline({ store, enrichmentAdapter });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });

  await worker.runOnce();
  const processed = store.getArticleById({ articleId: article.id });
  assert.equal(processed.status, 'pending_review');
});
