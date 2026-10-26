import assert from 'node:assert/strict';
import test from 'node:test';

import { VocabularyPoolScheduler } from '../src/vocabulary_pool_scheduler.js';
import { WordStore } from '../src/word_store.js';

test('fills vocabulary pool when language inventory is below minimum size', async () => {
  const store = new WordStore({ seed: false });
  const generationService = new RecordingGenerationService();
  const scheduler = new VocabularyPoolScheduler({
    store,
    generationService,
    config: schedulerConfig({ vocabGenerationBatchSize: 25 }),
    now: () => new Date('2026-05-05T00:00:00.000Z')
  });

  const result = await scheduler.runOnce({ targetLanguage: 'en' });

  assert.equal(result.mode, 'fill');
  assert.equal(generationService.calls.length, 1);
  assert.equal(generationService.calls[0].limit, 25);
  // Every level is empty, so the highest-targeted level (largest deficit, ties to higher level) goes first.
  assert.equal(generationService.calls[0].difficultyLevel, 'B2');
  assert.equal(result.level, 'B2');
  assert.equal(store.generationRuns.length, 1);
  assert.equal(store.generationRuns[0].status, 'success');
});

test('runs daily top-up once after vocabulary pool reaches minimum size', async () => {
  const store = new WordStore({ seed: false });
  for (let index = 0; index < 1000; index += 1) {
    store.insertWord(wordInput(index));
  }
  const generationService = new RecordingGenerationService();
  const scheduler = new VocabularyPoolScheduler({
    store,
    generationService,
    config: schedulerConfig({ vocabLevelTargets: { A1: 1000 }, vocabDailyGenerationCount: 10 }),
    now: () => new Date('2026-05-05T02:00:00.000Z')
  });

  const first = await scheduler.runOnce({ targetLanguage: 'en' });
  const second = await scheduler.runOnce({ targetLanguage: 'en' });

  assert.equal(first.mode, 'daily_top_up');
  assert.equal(second.mode, 'idle');
  assert.equal(generationService.calls.length, 1);
  assert.equal(generationService.calls[0].limit, 10);
});

test('targets the level with the largest deficit and steers away from existing terms', async () => {
  const store = new WordStore({ seed: false });
  for (let index = 0; index < 300; index += 1) {
    store.insertWord(wordInput(index));
  }
  const generationService = new RecordingGenerationService();
  const scheduler = new VocabularyPoolScheduler({
    store,
    generationService,
    config: schedulerConfig({ vocabLevelTargets: { A1: 200, B1: 300, B2: 50 } }),
    now: () => new Date('2026-05-05T00:00:00.000Z')
  });

  const result = await scheduler.runOnce({ targetLanguage: 'en' });

  assert.equal(result.level, 'B1');
  assert.equal(generationService.calls[0].difficultyLevel, 'B1');
  assert.ok(generationService.calls[0].avoidTerms.length > 0);
});

test('backs off exponentially while generation adds nothing, then recovers', async () => {
  const store = new WordStore({ seed: false });
  const generationService = new RecordingGenerationService();
  let clock = new Date('2026-05-05T00:00:00.000Z').getTime();
  const scheduler = new VocabularyPoolScheduler({
    store,
    generationService,
    config: schedulerConfig({ vocabFillIntervalSeconds: 60, vocabMaxBackoffSeconds: 1800 }),
    now: () => new Date(clock)
  });

  assert.equal((await scheduler.runOnce()).mode, 'fill');
  assert.equal((await scheduler.runOnce()).reason, 'backing_off');
  clock += 120_000;
  assert.equal((await scheduler.runOnce()).mode, 'fill');
  clock += 120_000;
  assert.equal((await scheduler.runOnce()).reason, 'backing_off');
  assert.equal(generationService.calls.length, 2);

  generationService.nextResult = [{ id: 'w' }];
  clock += 3_600_000;
  assert.equal((await scheduler.runOnce()).insertedCount, 1);
  assert.equal((await scheduler.runOnce()).mode, 'fill');
});

test('pauses background generation when the LLM hourly budget is nearly spent', async () => {
  const store = new WordStore({ seed: false });
  const generationService = new RecordingGenerationService();
  const scheduler = new VocabularyPoolScheduler({
    store,
    generationService,
    config: schedulerConfig({ llmReservedRequestsPerHour: 30 }),
    rateLimiter: { remainingHourlyBudget: () => 10 },
    now: () => new Date('2026-05-05T00:00:00.000Z')
  });

  const result = await scheduler.runOnce();

  assert.equal(result.reason, 'llm_budget_low');
  assert.equal(generationService.calls.length, 0);
});

class RecordingGenerationService {
  constructor() {
    this.calls = [];
  }

  async generateAndStore(input) {
    this.calls.push(input);
    return this.nextResult ?? [];
  }
}

function schedulerConfig(overrides = {}) {
  return {
    defaultSourceLanguage: 'vi',
    defaultTargetLanguage: 'en',
    vocabPoolMinSize: 1000,
    vocabLevelTargets: { A1: 200, A2: 250, B1: 300, B2: 300, C1: 200 },
    vocabFillIntervalSeconds: 60,
    vocabMaxBackoffSeconds: 1800,
    vocabGenerationBatchSize: 20,
    vocabDailyGenerationCount: 10,
    vocabDailyGenerationHourUtc: 0,
    vocabSchedulerLockTtlSeconds: 120,
    ...overrides
  };
}

function wordInput(index) {
  return {
    id: `word_${index}`,
    term: `word ${index}`,
    language: 'en',
    meaning_vi: 'meaning',
    part_of_speech: 'noun',
    ipa: '/wɜːd/',
    vietnamese_pronunciation: 'word',
    example: 'A sample word.',
    example_vi: 'Mot tu mau.',
    difficulty: 'A1',
    topics: ['sample'],
    created_at: `2026-05-04T00:00:${(index % 60).toString().padStart(2, '0')}.000Z`,
    updated_at: `2026-05-04T00:00:${(index % 60).toString().padStart(2, '0')}.000Z`
  };
}
