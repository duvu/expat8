// Integration tests: article ingest → processing state transitions → publish eligibility.
// These tests use the in-memory WordStore to exercise the full pipeline without a live DB.
import assert from 'node:assert/strict';
import test from 'node:test';

import { ArticleProcessingPipeline } from '../src/article_processing_pipeline.js';
import { ArticleProcessingWorker } from '../src/article_processing_worker.js';
import { WordStore } from '../src/word_store.js';

// Minimal suggestion adapter that returns one approved-quality suggestion.
function makeSuggestionAdapter(term = 'resilience') {
  return {
    async suggestVocabulary() {
      return [
        {
          term,
          language: 'en',
          meaning_vi: 'su kien cuong',
          part_of_speech: 'noun',
          ipa: '/rɪˈzɪliəns/',
          vietnamese_pronunciation: 'ri-zi-li-ens',
          example: `Teams need ${term} under pressure.`,
          example_vi: `Doi nhom can ${term} duoi ap luc.`,
          difficulty: 'B1',
          level: 'B1',
          topics: ['integration-test'],
          classification: 'article_keyword',
          suggestion_type: 'word',
          frequency: 2,
          confidence: 0.88
        }
      ];
    }
  };
}

test('article ingest: status transitions from pending_processing → processed', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'user_a',
    title: 'Ingest Integration',
    language: 'en',
    rawText: 'Resilience is a key trait for modern engineering teams under pressure.'
  });

  assert.equal(article.status, 'pending_processing', 'article starts pending');

  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: makeSuggestionAdapter('resilience')
  });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });

  const result = await worker.runOnce();
  assert.equal(result.processed, 1, 'worker reports one article processed');

  const processed = store.getArticleById({ articleId: article.id });
  assert.equal(processed.status, 'processed', 'article transitions to processed');
});

test('article ingest: vocabulary items created and accessible to owner after processing', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'user_b',
    title: 'Vocab Extraction Test',
    language: 'en',
    rawText: 'Consistency and reliability are fundamental to robust systems.'
  });

  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: makeSuggestionAdapter('reliability')
  });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });
  await worker.runOnce();

  const vocab = store.getArticleVocabulary({ articleId: article.id, userId: 'user_b' });
  assert.ok(
    vocab && Array.isArray(vocab.items) && vocab.items.length > 0,
    'owner can read vocabulary after processing'
  );
  assert.equal(vocab.items[0].classification, 'article_keyword');
});

test('vocabulary review: pending items are surfaced for admin approval', async () => {
  const store = new WordStore({ seed: false });
  store.createAdminArticle({
    adminUserId: 'admin_1',
    title: 'Review Batch',
    language: 'en',
    rawText: 'Automation enables consistent and repeatable deployments at scale.'
  });

  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: makeSuggestionAdapter('automation')
  });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });
  await worker.runOnce();

  const pendingItems = store.listVocabularyReviewItems({ status: 'pending' });
  assert.ok(pendingItems.length > 0, 'review items are created in pending state');
  assert.ok(
    pendingItems.every((item) => item.status === 'pending'),
    'all returned items are pending'
  );
});

test('publish eligibility: admin article requires vocabulary review before publish', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createAdminArticle({
    adminUserId: 'admin_2',
    title: 'Publish Eligibility',
    language: 'en',
    rawText: 'Observability tools enable engineers to detect anomalies early.'
  });

  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: makeSuggestionAdapter('observability')
  });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });
  await worker.runOnce();

  // Article is in pending_review; vocabulary must be reviewed before publish
  const afterProcessing = store.getArticleById({ articleId: article.id });
  assert.equal(afterProcessing.status, 'pending_review');

  // Approve all pending vocabulary
  const pending = store.listVocabularyReviewItems({ status: 'pending' });
  for (const item of pending) {
    store.reviewVocabularyItem({
      itemId: item.id,
      status: 'approved',
      reviewerUserId: 'admin_2'
    });
  }

  // Now publish
  const published = store.publishArticle({ articleId: article.id });
  assert.equal(published.status, 'published');
  assert.equal(published.visibility, 'published');
});

test('publish eligibility: non-owner cannot read unpublished vocabulary', async () => {
  const store = new WordStore({ seed: false });
  const article = store.createArticle({
    userId: 'owner_c',
    title: 'Private Article',
    language: 'en',
    rawText: 'Private notes for owner only.'
  });

  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: makeSuggestionAdapter('private')
  });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });
  await worker.runOnce();

  // Owner can read
  const ownerView = store.getArticleVocabulary({ articleId: article.id, userId: 'owner_c' });
  assert.ok(ownerView !== null && Array.isArray(ownerView.items), 'owner can access vocabulary');

  // Non-owner cannot read unpublished vocabulary
  const otherView = store.getArticleVocabulary({ articleId: article.id, userId: 'other_user' });
  assert.equal(otherView, null, 'non-owner cannot access unpublished vocabulary');
});

test('publish eligibility: non-owner can read published article vocabulary', async () => {
  const store = new WordStore({ seed: false });

  // Create and process an admin article, approve vocab, then publish
  const article = store.createAdminArticle({
    adminUserId: 'admin_pub',
    title: 'Public Article',
    language: 'en',
    rawText: 'Public knowledge grows when knowledge is shared openly.'
  });

  const pipeline = new ArticleProcessingPipeline({
    store,
    suggestionAdapter: makeSuggestionAdapter('knowledge')
  });
  const worker = new ArticleProcessingWorker({ store, pipeline, maxAttempts: 2 });
  await worker.runOnce();

  for (const item of store.listVocabularyReviewItems({ status: 'pending' })) {
    store.reviewVocabularyItem({ itemId: item.id, status: 'approved', reviewerUserId: 'admin_pub' });
  }
  store.publishArticle({ articleId: article.id });

  // Any authenticated user can now see the vocabulary
  const anyUser = store.getArticleVocabulary({ articleId: article.id, userId: 'random_user' });
  assert.ok(
    anyUser && Array.isArray(anyUser.items) && anyUser.items.length > 0,
    'published vocabulary is world-readable'
  );
});

test('content pack listing: in-memory store returns empty list (Postgres-only feature)', () => {
  const store = new WordStore({ seed: false });
  // In-memory store has no content packs seeded; verify the list API returns empty without error
  const packs = store.listContentPacks({ language: 'en' });
  assert.ok(Array.isArray(packs), 'listContentPacks returns an array');
  assert.equal(packs.length, 0, 'in-memory store starts with no content packs');
});
