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
    rawText: 'Reliable teams build reliable systems. They share knowledge across functions. The article also mentions reliable systems again.'
  });

  const enrichmentAdapter = {
    async suggestVocabulary({ chunk }) {
      return chunk.includes('share knowledge')
        ? [
            {
              term: 'share knowledge',
              language: 'en',
              meaning_vi: 'chia se kien thuc',
              part_of_speech: 'verb phrase',
              ipa: '/ʃer ˈnɑlɪdʒ/',
              vietnamese_pronunciation: 'sher nayldj',
              example: 'Teams share knowledge.',
              example_vi: 'Cac doi chia se kien thuc.',
              difficulty: 'A1',
              level: 'A1',
              topics: ['article-ingestion'],
              classification: 'article_phrase',
              suggestion_type: 'phrase',
              frequency: 1,
              confidence: 0.9
            }
          ]
        : [
            {
              term: 'reliable',
              language: 'en',
              meaning_vi: 'dang tin cay',
              part_of_speech: 'adjective',
              ipa: '/rɪˈlaɪəbl/',
              vietnamese_pronunciation: 'ri-lai-uh-bol',
              example: 'Reliable teams build better systems.',
              example_vi: 'Cac doi dang tin cay xay dung he thong tot hon.',
              difficulty: 'A1',
              level: 'A1',
              topics: ['article-ingestion'],
              classification: 'article_keyword',
              suggestion_type: 'word',
              frequency: 2,
              confidence: 0.85
            },
            {
              term: 'reliable',
              language: 'en',
              meaning_vi: 'dang tin cay',
              part_of_speech: 'adjective',
              ipa: '/rɪˈlaɪəbl/',
              vietnamese_pronunciation: 'ri-lai-uh-bol',
              example: 'Reliable systems stay reliable.',
              example_vi: 'He thong dang tin cay giu vung do tin cay.',
              difficulty: 'A1',
              level: 'A1',
              topics: ['article-ingestion'],
              classification: 'article_keyword',
              suggestion_type: 'word',
              frequency: 1,
              confidence: 0.8
            }
          ];
    }
  };

  const pipeline = new ArticleProcessingPipeline({ store, suggestionAdapter: enrichmentAdapter, maxChunkChars: 80 });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });

  const result = await worker.runOnce();

  assert.equal(result.processed, 1);
  const processedArticle = store.getArticleById({ articleId: article.id });
  assert.equal(processedArticle.status, 'processed');
  assert.equal(store.articleTermsById.size, 2);
  assert.equal(store.wordSensesById.size, 2);
  const persisted = [...store.articleTermsById.values()];
  assert.ok(persisted.some((item) => item.classification === 'article_keyword'));
  assert.ok(persisted.some((item) => item.classification === 'article_phrase'));
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
    async suggestVocabulary() {
      return [
        {
          term: 'workflow',
          language: 'en',
          meaning_vi: 'quy trinh',
          part_of_speech: 'noun',
          ipa: '/ˈwɜrkfloʊ/',
          vietnamese_pronunciation: 'uoc-flow',
          example: 'The workflow needs review.',
          example_vi: 'Quy trinh can duoc xem xet.',
          difficulty: 'A1',
          level: 'A1',
          topics: ['article-ingestion'],
          classification: 'article_keyword',
          suggestion_type: 'word',
          frequency: 1,
          confidence: 0.7
        }
      ];
    }
  };

  const pipeline = new ArticleProcessingPipeline({ store, suggestionAdapter: enrichmentAdapter });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });

  await worker.runOnce();
  const processed = store.getArticleById({ articleId: article.id });
  assert.equal(processed.status, 'pending_review');
});
