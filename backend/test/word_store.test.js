import assert from 'node:assert/strict';
import test from 'node:test';

import {
  WordStore,
  normalizeSpeakingEvent,
  isSpeakingEvent,
  SPEAKING_EVENT_TYPES,
  toApiSpeakingPrompt,
  toApiWorkplaceSentence
} from '../src/word_store.js';

test('prevents duplicate words by language and normalized term', () => {
  const store = new WordStore({ seed: false });

  const first = store.insertWord(wordInput({ term: 'Reliable' }));
  const second = store.insertWord(wordInput({ term: ' reliable ' }));

  assert.equal(first.inserted, true);
  assert.equal(second.inserted, false);
  assert.equal(first.word.id, second.word.id);
});

test('reports content pipeline health from queued jobs, passages, and shadowing videos', () => {
  const store = new WordStore({ seed: false });
  const article = store.createAdminArticle({
    adminUserId: 'admin_pipeline',
    title: 'Pipeline article',
    language: 'en',
    rawText: 'Article content for pipeline health.'
  });
  const failedArticleJob = store.enqueueArticleProcessingJob({ articleId: article.id });
  store.completeArticleProcessingJob({ jobId: failedArticleJob.id, status: 'failed', errorMessage: 'boom' });
  store.createPassage({
    title: 'Pending passage',
    language: 'en',
    rawText: 'A'.repeat(80),
    ownerType: 'user',
    ownerUserId: 'user_pipeline'
  });
  const failedPassage = store.createPassage({
    title: 'Failed passage',
    language: 'en',
    rawText: 'B'.repeat(80),
    ownerType: 'admin',
    visibility: 'published'
  });
  store.updatePassage({ passageId: failedPassage.id, status: 'failed', processing_error: 'segmentation failed' });
  store.createShadowingVideoEntry({
    deviceId: 'device_pipeline',
    resolvedVideo: {
      sourceType: 'youtube',
      providerVideoId: 'pipeline_video',
      sourceUrl: 'https://youtu.be/pipeline_video',
      title: 'Pipeline video',
      transcriptSource: 'manual',
      segments: [{ position: 0, start_ms: 0, end_ms: 1000, text: 'Hello.' }]
    }
  });

  const health = store.getContentPipelineHealth();

  assert.equal(health.articles.pending_count, 1);
  assert.equal(health.articles.failed_count, 1);
  assert.equal(typeof health.articles.last_processed_at, 'string');
  assert.equal(health.memorization.pending_count, 1);
  assert.equal(health.memorization.failed_count, 1);
  assert.equal(typeof health.memorization.last_processed_at, 'string');
  assert.equal(health.shadowing.pending_count, 0);
  assert.equal(health.shadowing.failed_count, 0);
  assert.equal(typeof health.shadowing.last_processed_at, 'string');
});

test('syncs study events idempotently', () => {
  const store = new WordStore({ seed: false });

  const payload = {
    deviceId: 'device_1',
    events: [
      {
        client_event_id: 'evt_1',
        server_word_id: 'word_1',
        local_word_id: 'local_1',
        rating: 'easy',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  };

  const first = store.syncStudyEvents(payload);
  const second = store.syncStudyEvents(payload);

  assert.deepEqual(first.accepted_event_ids, ['evt_1']);
  assert.deepEqual(second.accepted_event_ids, []);
  assert.deepEqual(second.duplicates, ['evt_1']);
  assert.equal(store.studyEventsByClientId.size, 1);
  assert.equal(first.proficiency.level, 'A1');
});

test('syncing an empty study-event batch returns current proficiency', () => {
  const store = new WordStore({ seed: false });

  const result = store.syncStudyEvents({
    deviceId: 'device_empty_sync',
    events: []
  });

  assert.deepEqual(result.accepted_event_ids, []);
  assert.deepEqual(result.rejected_events, []);
  assert.equal(result.proficiency.level, 'A1');
});

test('syncing only rejected study events returns current proficiency', () => {
  const store = new WordStore({ seed: false });

  const result = store.syncStudyEvents({
    deviceId: 'device_rejected_sync',
    events: [
      {
        client_event_id: 'evt_rejected',
        server_word_id: 'word_1',
        rating: 'remembered',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  });

  assert.deepEqual(result.accepted_event_ids, []);
  assert.deepEqual(result.rejected_events, [
    {
      client_event_id: 'evt_rejected',
      event_id: null,
      reason: 'invalid_rating'
    }
  ]);
  assert.equal(result.proficiency.level, 'A1');
  assert.equal(store.studyEventsByClientId.size, 0);
});

test('stores repeated study attempts and projects the latest word state', () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'state_word', term: 'stateful' }));

  store.recordStudyEvent({
    deviceId: 'device_state',
    event: {
      client_event_id: 'evt_state_1',
      server_word_id: 'state_word',
      local_word_id: 'local_state',
      rating: 'hard',
      occurred_at: '2026-05-04T10:30:00.000Z'
    }
  });
  store.recordStudyEvent({
    deviceId: 'device_state',
    event: {
      client_event_id: 'evt_state_2',
      server_word_id: 'state_word',
      local_word_id: 'local_state',
      rating: 'easy',
      occurred_at: '2026-05-04T10:35:00.000Z'
    }
  });

  const state = store.wordStateFor({
    deviceId: 'device_state',
    wordId: 'state_word',
    language: 'en'
  });

  assert.equal(store.studyEventsByClientId.size, 2);
  assert.equal(state.last_rating, 'easy');
  assert.equal(state.status, 'completed');
});

test('replaces cached word inventory and caps it at 1000 known ids', () => {
  const store = new WordStore({ seed: false });
  for (let index = 0; index < 1005; index += 1) {
    store.insertWord(wordInput({ id: `cache_${index}`, term: `cache ${index}` }));
  }

  const result = store.replaceCachedWordIds({
    deviceId: 'device_cache',
    wordIds: [...Array.from({ length: 1005 }, (_, index) => `cache_${index}`), 'unknown_word'],
    observedAt: '2026-05-05T00:00:00.000Z'
  });

  assert.equal(result.stored_count, 1000);
  assert.deepEqual(result.unknown_server_word_ids, ['unknown_word']);
  assert.equal(store.cachedWordIdsFor({ deviceId: 'device_cache' }).size, 1000);
});

test('levels up after five consecutive too_easy ratings', () => {
  const store = new WordStore({ seed: false });

  for (let index = 0; index < 5; index += 1) {
    const result = store.recordStudyEvent({
      deviceId: 'device_1',
      event: {
        client_event_id: `evt_${index + 1}`,
        server_word_id: 'word_1',
        local_word_id: 'local_1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:30:0${index}.000Z`
      }
    });

    if (index < 4) {
      assert.equal(result.proficiency.level_changed, false);
      assert.equal(result.proficiency.consecutive_count, index + 1);
    } else {
      assert.equal(result.proficiency.level_changed, true);
      assert.equal(result.proficiency.level, 'A2');
      assert.equal(result.proficiency.previous_level, 'A1');
    }
  }
});

test('levels down after five consecutive hard ratings without dropping below A1', () => {
  const store = new WordStore({ seed: false });

  for (let index = 0; index < 5; index += 1) {
    store.recordStudyEvent({
      deviceId: 'device_up',
      event: {
        client_event_id: `evt_up_${index + 1}`,
        server_word_id: 'word_1',
        local_word_id: 'local_1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:35:0${index}.000Z`
      }
    });
  }

  for (let index = 0; index < 5; index += 1) {
    const result = store.recordStudyEvent({
      deviceId: 'device_up',
      event: {
        client_event_id: `evt_down_${index + 1}`,
        server_word_id: 'word_1',
        local_word_id: 'local_1',
        rating: 'hard',
        occurred_at: `2026-05-04T10:36:0${index}.000Z`
      }
    });

    if (index === 4) {
      assert.equal(result.proficiency.level_changed, true);
      assert.equal(result.proficiency.level, 'A1');
      assert.equal(result.proficiency.previous_level, 'A2');
    }
  }
});

test('does not advance beyond C2', () => {
  const store = new WordStore({ seed: false });

  for (let wave = 0; wave < 6; wave += 1) {
    const result = store.recordStudyEvent({
      deviceId: 'device_c2',
      event: {
        client_event_id: `evt_c2_${wave + 1}`,
        server_word_id: 'word_1',
        local_word_id: 'local_1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:39:0${wave}.000Z`
      }
    });

    if (wave === 4) {
      assert.equal(result.proficiency.level, 'A2');
    }
  }

  for (let block = 0; block < 20; block += 1) {
    store.recordStudyEvent({
      deviceId: 'device_c2',
      event: {
        client_event_id: `evt_c2_more_${block + 1}`,
        server_word_id: 'word_1',
        local_word_id: 'local_1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:${40 + Math.floor(block / 10)}:${(block % 10).toString().padStart(2, '0')}.000Z`
      }
    });
  }

  const proficiency = store.getProficiency({ deviceId: 'device_c2', language: 'en' });
  assert.equal(proficiency.level, 'C2');
});

test('resets consecutive counter when rating type changes', () => {
  const store = new WordStore({ seed: false });

  for (let index = 0; index < 3; index += 1) {
    store.recordStudyEvent({
      deviceId: 'device_reset',
      event: {
        client_event_id: `evt_reset_${index + 1}`,
        server_word_id: 'word_1',
        local_word_id: 'local_1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:37:0${index}.000Z`
      }
    });
  }

  const result = store.recordStudyEvent({
    deviceId: 'device_reset',
    event: {
      client_event_id: 'evt_reset_final',
      server_word_id: 'word_1',
      local_word_id: 'local_1',
      rating: 'easy',
      occurred_at: '2026-05-04T10:37:09.000Z'
    }
  });

  assert.equal(result.proficiency.level_changed, false);
  assert.equal(result.proficiency.consecutive_count, 1);
  assert.equal(result.proficiency.consecutive_rating_type, 'easy');
});

test('auto-initializes proficiency for a new device', () => {
  const store = new WordStore({ seed: false });

  const proficiency = store.getProficiency({ deviceId: 'fresh_device', language: 'en' });

  assert.equal(proficiency.level, 'A1');
  assert.equal(proficiency.language, 'en');
});

test('learning cards returns ten new words and records active claims', () => {
  const store = new WordStore({ seed: false });
  for (let index = 0; index < 12; index += 1) {
    store.insertWord(
      wordInput({
        id: `word_batch_${index}`,
        term: `batch ${index}`,
        created_at: `2026-05-05T00:${index.toString().padStart(2, '0')}:00.000Z`
      })
    );
  }

  const first = store.learningCards({
    deviceId: 'anonymous_batch',
    targetLanguage: 'en',
    limit: 10,
    now: '2026-05-05T01:00:00.000Z'
  });
  const second = store.learningCards({
    deviceId: 'anonymous_batch',
    targetLanguage: 'en',
    limit: 10,
    now: '2026-05-05T01:01:00.000Z'
  });

  assert.equal(first.items.length, 10);
  assert.deepEqual(first.target_mix, { new: 2, review: 8 });
  assert.deepEqual(first.actual_mix, { new: 10, review: 0 });
  assert.equal(store.cachedWordIdsFor({ deviceId: 'anonymous_batch' }).size, 12);
  assert.equal(second.items.length, 2);
});

test('learning cards applies 85/15 SRS split: due review items returned first, remainder filled with new', () => {
  const store = new WordStore({ seed: false });

  // Insert 10 words that will be reviewed (study event sets next_review_at)
  for (let index = 0; index < 10; index += 1) {
    store.insertWord(wordInput({ id: `word_review_${index}`, term: `review ${index}` }));
  }
  // Insert 5 additional new words (never seen)
  for (let index = 0; index < 5; index += 1) {
    store.insertWord(wordInput({ id: `word_new_${index}`, term: `new ${index}` }));
  }

  // Record 'too_hard' study events in the past so next_review_at <= now
  for (let index = 0; index < 10; index += 1) {
    store.recordStudyEvent({
      deviceId: 'device_srs',
      language: 'en',
      event: {
        client_event_id: `evt_srs_${index}`,
        server_word_id: `word_review_${index}`,
        rating: 'too_hard',
        occurred_at: '2026-05-05T00:00:00.000Z'
      }
    });
  }

  // now is well past next_review_at (was occurredAt + 5 min = 00:05), so all 10 are due
  const result = store.learningCards({
    deviceId: 'device_srs',
    targetLanguage: 'en',
    limit: 10,
    now: '2026-05-05T01:00:00.000Z'
  });

  const reviewCards = result.items.filter((c) => c.cardType === 'review');
  const newCards = result.items.filter((c) => c.cardType === 'new');

  assert.equal(result.items.length, 10);
  assert.deepEqual(result.target_mix, { new: 2, review: 8 });
  assert.deepEqual(result.actual_mix, { new: 2, review: 8 });
  assert.equal(reviewCards.length, 8);
  assert.equal(newCards.length, 2);
  assert.ok(reviewCards.every((c) => c.selectionReason === 'srs_due'));
  assert.ok(newCards.every((c) => c.selectionReason === 'new_available'));
});

test('learning cards exclude anonymous history after sign-in', () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_seen', term: 'seen', created_at: '2026-05-05T00:00:00.000Z' }));
  store.insertWord(wordInput({ id: 'word_fresh', term: 'fresh', created_at: '2026-05-05T00:01:00.000Z' }));

  store.recordStudyEvent({
    deviceId: 'anonymous_history',
    event: {
      client_event_id: 'evt_history',
      server_word_id: 'word_fresh',
      local_word_id: 'local_fresh',
      rating: 'easy',
      occurred_at: '2026-05-05T02:00:00.000Z'
    }
  });

  const result = store.learningCards({
    deviceId: 'anonymous_history',
    userId: 'user_history',
    targetLanguage: 'en',
    limit: 10,
    now: '2026-05-05T03:00:00.000Z'
  });

  assert.deepEqual(
    result.items.map((card) => card.word.id),
    ['word_seen']
  );
});

test('reprocessArticle clears existing vocabulary so double-reprocess yields no duplicates', () => {
  const store = new WordStore({ seed: false });
  const article = store.createAdminArticle({
    adminUserId: 'admin_1',
    title: 'Test Article',
    language: 'en',
    rawText: 'Some text about resilience and tenacity.'
  });

  const vocabItems = [
    { term: 'resilience', language: 'en', meaning_vi: 'suc ben bi', ipa: '/rɪˈzɪliəns/' },
    { term: 'tenacity', language: 'en', meaning_vi: 'su kien tri', ipa: '/tɪˈnæsɪti/' }
  ];

  // First process
  store.persistArticleVocabulary({ articleId: article.id, items: vocabItems });
  const afterFirst = [...store.articleTermsById.values()].filter((at) => at.article_id === article.id);
  assert.equal(afterFirst.length, 2, 'expected 2 article_terms after first process');

  // Reprocess (simulating worker picking up the job a second time)
  store.reprocessArticle({ articleId: article.id });
  store.persistArticleVocabulary({ articleId: article.id, items: vocabItems });
  const afterSecond = [...store.articleTermsById.values()].filter((at) => at.article_id === article.id);
  assert.equal(afterSecond.length, 2, 'expected 2 article_terms after reprocess (no duplicates)');

  const reviewItems = [...store.vocabularyReviewItemsById.values()].filter((ri) => ri.article_id === article.id);
  assert.equal(reviewItems.length, 2, 'expected 2 vocabulary_review_items after reprocess (no duplicates)');
});

test('stub vocabulary items have approved=false regardless of article type', () => {
  const store = new WordStore({ seed: false });
  const adminArticle = store.createAdminArticle({
    adminUserId: 'admin_stub',
    title: 'Admin Article',
    language: 'en',
    rawText: 'content'
  });
  const userArticle = store.createArticle({
    userId: 'user_stub',
    title: 'User Article',
    language: 'en',
    rawText: 'content'
  });

  const stubItem = { term: 'perseverance', language: 'en', meaning_vi: 'su kien tri', isStub: true };
  const normalItem = { term: 'resilience', language: 'en', meaning_vi: 'suc chong chiu' };

  // User article with LLM enrichment (non-stub) → auto-approved
  store.persistArticleVocabulary({ articleId: userArticle.id, items: [normalItem] });
  const userNormalReview = [...store.vocabularyReviewItemsById.values()].find((ri) => ri.article_id === userArticle.id);
  assert.equal(userNormalReview.status, 'approved', 'user article non-stub should be approved');

  // Admin article with stubs → pending (requires review)
  store.persistArticleVocabulary({ articleId: adminArticle.id, items: [stubItem] });
  const adminStubReview = [...store.vocabularyReviewItemsById.values()].find((ri) => ri.article_id === adminArticle.id);
  assert.equal(adminStubReview.status, 'pending', 'admin article stub should be pending');

  // User article with stub → also pending (stubs never auto-approve)
  const userArticle2 = store.createArticle({
    userId: 'user_stub2',
    title: 'User Article 2',
    language: 'en',
    rawText: 'content'
  });
  store.persistArticleVocabulary({ articleId: userArticle2.id, items: [stubItem] });
  const userStubReview = [...store.vocabularyReviewItemsById.values()].find((ri) => ri.article_id === userArticle2.id);
  assert.equal(userStubReview.status, 'pending', 'user article stub should also be pending');
});

test('approved article vocabulary is bridged into words pool and served by learningCards', () => {
  const store = new WordStore({ seed: false });
  const user = store.registerUser({ identifier: 'bridge_user@test.com', password: 'pass_bridge_123!' });
  const article = store.createArticle({
    userId: user.user.id,
    title: 'Bridge Test Article',
    language: 'en',
    rawText: 'Resilience and tenacity matter.'
  });

  const items = [
    { term: 'resilience', language: 'en', meaning_vi: 'suc ben bi', ipa: '/rɪˈzɪliəns/', level: 'B2' },
    { term: 'tenacity', language: 'en', meaning_vi: 'su kien tri', ipa: '/tɪˈnæsɪti/', level: 'C1' }
  ];
  store.persistArticleVocabulary({ articleId: article.id, items });

  // Both words should now be in the words pool
  const wordTerms = [...store.words.values()].map((w) => w.term);
  assert.ok(wordTerms.includes('resilience'), 'resilience should be in words pool');
  assert.ok(wordTerms.includes('tenacity'), 'tenacity should be in words pool');

  // learningCards should serve them as new cards for a fresh device
  const result = store.learningCards({ deviceId: 'device_bridge_test', targetLanguage: 'en' });
  const cardTerms = result.items.map((c) => c.word.term);
  assert.ok(cardTerms.includes('resilience'), 'learningCards should include resilience');
  assert.ok(cardTerms.includes('tenacity'), 'learningCards should include tenacity');

  // generation_source should identify article-sourced words
  const bridgedWord = [...store.words.values()].find((w) => w.term === 'resilience');
  assert.equal(bridgedWord.generation_source, 'article_vocabulary');
});

test('admin article vocabulary is NOT bridged into words pool (requires review)', () => {
  const store = new WordStore({ seed: false });
  const adminArticle = store.createAdminArticle({
    adminUserId: 'admin_bridge',
    title: 'Admin Bridge Article',
    language: 'en',
    rawText: 'Some curated content.'
  });

  store.persistArticleVocabulary({
    articleId: adminArticle.id,
    items: [{ term: 'curation', language: 'en', meaning_vi: 'su tuyen chon', ipa: '/kjʊˈreɪʃn/', level: 'B2' }]
  });

  // Word should NOT be in the words pool (pending_review)
  const wordTerms = [...store.words.values()].map((w) => w.term);
  assert.ok(!wordTerms.includes('curation'), 'admin article vocab should NOT be in words pool');
});

test('recentWorkplaceSentences only returns sentences linked to published articles and preserves dedupe across articles', () => {
  const store = new WordStore({ seed: false });
  const privateArticle = store.createArticle({
    userId: 'owner_sentence_private',
    title: 'Private meeting notes',
    language: 'en',
    rawText: 'Private article content'
  });
  const publishedArticle = store.createAdminArticle({
    adminUserId: 'admin_sentence_published',
    title: 'Published meeting notes',
    language: 'en',
    rawText: 'Published article content'
  });

  const sharedSentence = {
    text: 'Could we move this meeting to tomorrow morning?',
    language: 'en',
    meaning_vi: 'Chung ta co the chuyen cuoc hop nay sang sang mai duoc khong?',
    topic: 'meetings'
  };

  store.persistArticleWorkplaceSentences({ articleId: privateArticle.id, items: [sharedSentence] });
  assert.deepEqual(store.recentWorkplaceSentences({ targetLanguage: 'en' }), []);

  store.persistArticleWorkplaceSentences({ articleId: publishedArticle.id, items: [sharedSentence] });
  store.publishArticle({ articleId: publishedArticle.id });

  const recent = store.recentWorkplaceSentences({ targetLanguage: 'en' });
  assert.equal(recent.length, 1);
  assert.equal(recent[0].source_article_id, publishedArticle.id);
  assert.equal(recent[0].source_title, 'Published meeting notes');

  const apiSentence = toApiWorkplaceSentence(recent[0]);
  assert.equal(apiSentence.text, sharedSentence.text);
  assert.equal(apiSentence.topic, 'meetings');
});

test('additive cache claims are idempotent and filter unknown words', () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_claim', term: 'claim' }));

  const first = store.addCachedWordIds({
    deviceId: 'anonymous_claim',
    wordIds: ['word_claim', 'missing_claim'],
    observedAt: '2026-05-05T01:00:00.000Z'
  });
  const second = store.addCachedWordIds({
    deviceId: 'anonymous_claim',
    wordIds: ['word_claim'],
    observedAt: '2026-05-05T01:01:00.000Z'
  });

  assert.equal(first.stored_count, 1);
  assert.deepEqual(first.unknown_server_word_ids, ['missing_claim']);
  assert.equal(second.stored_count, 1);
  assert.equal(store.cachedWordIdsFor({ deviceId: 'anonymous_claim' }).size, 1);
});

// ---- Speaking event tests ----

test('SPEAKING_EVENT_TYPES includes speaking_drill_completed', () => {
  assert.ok(SPEAKING_EVENT_TYPES.includes('speaking_drill_completed'));
  assert.ok(SPEAKING_EVENT_TYPES.includes('loop_completed'));
  assert.equal(SPEAKING_EVENT_TYPES.length, 9);
});

test('isSpeakingEvent returns true for all speaking event types', () => {
  for (const type of SPEAKING_EVENT_TYPES) {
    assert.ok(isSpeakingEvent({ event_type: type }), `expected isSpeakingEvent for ${type}`);
  }
  assert.equal(isSpeakingEvent({ event_type: 'easy' }), false);
  assert.equal(isSpeakingEvent({ event_type: 'speaking_magic_score' }), false);
});

test('normalizeSpeakingEvent accepts all 9 speaking event types', () => {
  const base = {
    attempt_id: 'attempt_x',
    occurred_at: '2026-05-10T10:00:00.000Z'
  };
  for (const type of SPEAKING_EVENT_TYPES) {
    let event = { event_type: type, ...base };
    if (type === 'speaking_drill_completed') {
      event = { ...event, prompts_attempted: 5, total_duration_ms: 180000 };
    }
    if (type === 'loop_completed') {
      event = { ...event, duration_ms: 60000, prompts_count: 5 };
    }
    const normalized = normalizeSpeakingEvent({ deviceId: 'device_test', event });
    assert.equal(normalized.event_type, type);
  }
});

test('normalizeSpeakingEvent rejects unknown speaking event type', () => {
  assert.throws(
    () =>
      normalizeSpeakingEvent({
        deviceId: 'd',
        event: { event_type: 'speaking_magic_score', attempt_id: 'a', occurred_at: '2026-01-01T00:00:00Z' }
      }),
    { message: 'invalid_speaking_event_type' }
  );
});

test('normalizeSpeakingEvent rejects forbidden audio fields', () => {
  assert.throws(
    () =>
      normalizeSpeakingEvent({
        deviceId: 'd',
        event: {
          event_type: 'speaking_recorded',
          attempt_id: 'a',
          occurred_at: '2026-01-01T00:00:00Z',
          local_audio_path: '/tmp/x.m4a'
        }
      }),
    { message: 'forbidden_audio_field' }
  );
});

test('normalizeSpeakingEvent requires prompts_attempted and total_duration_ms for drill_completed', () => {
  const base = { event_type: 'speaking_drill_completed', attempt_id: 'sess_1', occurred_at: '2026-05-10T10:00:00Z' };
  assert.throws(() => normalizeSpeakingEvent({ deviceId: 'd', event: { ...base, total_duration_ms: 180000 } }), {
    message: 'missing_required_field'
  });
  assert.throws(() => normalizeSpeakingEvent({ deviceId: 'd', event: { ...base, prompts_attempted: 5 } }), {
    message: 'missing_required_field'
  });
  const ok = normalizeSpeakingEvent({
    deviceId: 'd',
    event: { ...base, prompts_attempted: 5, total_duration_ms: 180000 }
  });
  assert.equal(ok.prompts_attempted, 5);
  assert.equal(ok.total_duration_ms, 180000);
});

test('normalizeSpeakingEvent accepts event without attempt_id in lenient mode (default)', () => {
  const event = { event_type: 'speaking_recorded', occurred_at: '2026-01-01T00:00:00Z' };
  const normalized = normalizeSpeakingEvent({ deviceId: 'd', event });
  assert.equal(normalized.attempt_id, null);
});

test('normalizeSpeakingEvent accepts event with attempt_id in lenient mode', () => {
  const event = { event_type: 'speaking_recorded', attempt_id: 'sess_abc', occurred_at: '2026-01-01T00:00:00Z' };
  const normalized = normalizeSpeakingEvent({ deviceId: 'd', event });
  assert.equal(normalized.attempt_id, 'sess_abc');
});

test('normalizeSpeakingEvent accepts event with attempt_id in strict mode', () => {
  const event = { event_type: 'speaking_recorded', attempt_id: 'sess_xyz', occurred_at: '2026-01-01T00:00:00Z' };
  const normalized = normalizeSpeakingEvent({ deviceId: 'd', event, strict: true });
  assert.equal(normalized.attempt_id, 'sess_xyz');
});

test('normalizeSpeakingEvent rejects event without attempt_id in strict mode', () => {
  const event = { event_type: 'speaking_recorded', occurred_at: '2026-01-01T00:00:00Z' };
  assert.throws(() => normalizeSpeakingEvent({ deviceId: 'd', event, strict: true }), {
    message: 'missing_required_field'
  });
});

test('WordStore.recordSpeakingEvent accepts missing attempt_id in lenient mode', () => {
  const store = new WordStore({ seed: false, strictAttemptId: false });
  const result = store.recordSpeakingEvent({
    deviceId: 'dev1',
    event: { event_type: 'speaking_recorded', client_event_id: 'ev_lenient', occurred_at: '2026-01-01T00:00:00Z' }
  });
  assert.ok(result.eventId);
  assert.equal(result.idempotent, false);
});

test('WordStore.recordSpeakingEvent rejects missing attempt_id in strict mode', () => {
  const store = new WordStore({ seed: false, strictAttemptId: true });
  assert.throws(
    () =>
      store.recordSpeakingEvent({
        deviceId: 'dev1',
        event: { event_type: 'speaking_recorded', client_event_id: 'ev_strict', occurred_at: '2026-01-01T00:00:00Z' }
      }),
    { message: 'missing_required_field' }
  );
});

test('speaking events do not affect proficiency level', () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_sp1', term: 'hello' }));

  // Sync 4 easy ratings to nearly reach level-up threshold
  for (let i = 0; i < 4; i++) {
    store.syncStudyEvents({
      deviceId: 'device_prof_isolation',
      language: 'en',
      userId: null,
      events: [
        {
          client_event_id: `easy_${i}`,
          server_word_id: 'word_sp1',
          rating: 'too_easy',
          occurred_at: `2026-05-10T10:0${i}:00.000Z`
        }
      ]
    });
  }

  const before = store.getProficiency({ deviceId: 'device_prof_isolation', language: 'en' });

  // Sync 10 speaking events of all types
  const speakingEvents = [
    {
      client_event_id: 'sp_viewed',
      event_type: 'speaking_prompt_viewed',
      speaking: { attempt_id: 'a1', prompt_id: 'p1' }
    },
    {
      client_event_id: 'sp_played',
      event_type: 'speaking_sample_played',
      speaking: { attempt_id: 'a1', prompt_id: 'p1' }
    },
    {
      client_event_id: 'sp_recorded',
      event_type: 'speaking_recorded',
      speaking: { attempt_id: 'a1', duration_ms: 3000, retry_count: 0 }
    },
    { client_event_id: 'sp_retried', event_type: 'speaking_retried', speaking: { attempt_id: 'a1', retry_count: 1 } },
    {
      client_event_id: 'sp_rated_clear',
      event_type: 'speaking_self_rated_clear',
      speaking: { attempt_id: 'a1', self_rating: 'clear' }
    },
    {
      client_event_id: 'sp_rated_hes',
      event_type: 'speaking_self_rated_hesitated',
      speaking: { attempt_id: 'a2', self_rating: 'hesitated' }
    },
    {
      client_event_id: 'sp_rated_cnt',
      event_type: 'speaking_self_rated_could_not_say',
      speaking: { attempt_id: 'a3', self_rating: 'could_not_say' }
    },
    {
      client_event_id: 'sp_drill',
      event_type: 'speaking_drill_completed',
      speaking: { attempt_id: 'sess1', prompts_attempted: 5, prompts_completed: 4, total_duration_ms: 180000 }
    }
  ].map((e) => ({ ...e, occurred_at: '2026-05-10T11:00:00.000Z', language: 'en' }));

  store.syncStudyEvents({
    deviceId: 'device_prof_isolation',
    language: 'en',
    userId: null,
    events: speakingEvents
  });

  const after = store.getProficiency({ deviceId: 'device_prof_isolation', language: 'en' });
  assert.equal(before.level, after.level, 'speaking events must not change proficiency level');
  assert.equal(store.speakingEventsByKey.size, 8);
  assert.equal(store.studyEventsByClientId.size, 4); // only non-speaking events
});

test('getSpeakingSummary returns retry_rate, drill_sessions_completed, first_recording_at', () => {
  const store = new WordStore({ seed: false });

  // New device: zero state
  const empty = store.getSpeakingSummary({ deviceId: 'device_summary_new', language: 'en' });
  assert.equal(empty.spoken_sentence_count, 0);
  assert.equal(empty.retry_rate, 0);
  assert.equal(empty.drill_sessions_completed, 0);
  assert.equal(empty.first_recording_at, null);

  // Seed speaking events
  const events = [
    {
      client_event_id: 'sum_rec1',
      event_type: 'speaking_recorded',
      speaking: { attempt_id: 'a1', duration_ms: 3000, retry_count: 0 }
    },
    {
      client_event_id: 'sum_rec2',
      event_type: 'speaking_recorded',
      speaking: { attempt_id: 'a2', duration_ms: 4000, retry_count: 0 }
    },
    { client_event_id: 'sum_retry', event_type: 'speaking_retried', speaking: { attempt_id: 'a2', retry_count: 1 } },
    {
      client_event_id: 'sum_drill',
      event_type: 'speaking_drill_completed',
      speaking: { attempt_id: 'sess1', prompts_attempted: 5, total_duration_ms: 170000 }
    }
  ].map((e) => ({ ...e, occurred_at: '2026-05-10T12:00:00.000Z', language: 'en' }));

  store.syncStudyEvents({ deviceId: 'device_summary_new', language: 'en', userId: null, events });

  const summary = store.getSpeakingSummary({ deviceId: 'device_summary_new', language: 'en', weekStart: '2026-05-05' });
  assert.equal(summary.spoken_sentence_count, 2);
  assert.equal(summary.retry_count, 1);
  assert.equal(summary.retry_rate, 0.5); // 1 retry / 2 recordings
  assert.equal(summary.drill_sessions_completed, 1);
  assert.equal(summary.first_recording_at, '2026-05-10T12:00:00.000Z');
});

test('toApiSpeakingPrompt includes word_sense_id for mobile sync', () => {
  const store = new WordStore({ seed: false });
  const prompt = store.createSpeakingPrompt({
    word_sense_id: 'ws_test_123',
    target_text: 'Hello world',
    difficulty: 'A1',
    status: 'approved'
  });

  const api = toApiSpeakingPrompt(prompt);
  assert.equal(api.word_sense_id, 'ws_test_123', 'word_sense_id should be present in API response');
  assert.equal(api.id, prompt.id);
  assert.equal(api.target_text, 'Hello world');
  assert.equal(toApiSpeakingPrompt(null), null, 'null prompt returns null');
});

function wordInput(overrides = {}) {
  return {
    term: 'reliable',
    language: 'en',
    meaning_vi: 'dang tin cay',
    part_of_speech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamese_pronunciation: 'ri-lai-uh-bol',
    example: 'She is a reliable teammate.',
    example_vi: 'Co ay la mot dong doi dang tin cay.',
    difficulty: 'B1',
    topics: ['work'],
    ...overrides
  };
}
