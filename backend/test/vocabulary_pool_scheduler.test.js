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
    config: schedulerConfig({ vocabPoolMinSize: 1000, vocabGenerationBatchSize: 25 }),
    now: () => new Date('2026-05-05T00:00:00.000Z')
  });

  const result = await scheduler.runOnce({ targetLanguage: 'en' });

  assert.equal(result.mode, 'fill');
  assert.equal(generationService.calls.length, 1);
  assert.equal(generationService.calls[0].limit, 25);
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
    config: schedulerConfig({ vocabPoolMinSize: 1000, vocabDailyGenerationCount: 10 }),
    now: () => new Date('2026-05-05T02:00:00.000Z')
  });

  const first = await scheduler.runOnce({ targetLanguage: 'en' });
  const second = await scheduler.runOnce({ targetLanguage: 'en' });

  assert.equal(first.mode, 'daily_top_up');
  assert.equal(second.mode, 'idle');
  assert.equal(generationService.calls.length, 1);
  assert.equal(generationService.calls[0].limit, 10);
});

class RecordingGenerationService {
  constructor() {
    this.calls = [];
  }

  async generateAndStore(input) {
    this.calls.push(input);
    return [];
  }
}

function schedulerConfig(overrides = {}) {
  return {
    defaultSourceLanguage: 'vi',
    defaultTargetLanguage: 'en',
    vocabPoolMinSize: 1000,
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
