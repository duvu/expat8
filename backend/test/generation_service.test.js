import assert from 'node:assert/strict';
import test from 'node:test';

import { VocabularyGenerationService, parseVocabularyJson } from '../src/generation_service.js';
import { WordStore } from '../src/word_store.js';

test('parses valid structured output', () => {
  const items = parseVocabularyJson(
    JSON.stringify({
      items: [wordInput()]
    })
  );

  assert.equal(items.length, 1);
  assert.equal(items[0].term, 'reliable');
});

test('rejects invalid json output', () => {
  assert.deepEqual(parseVocabularyJson('not json'), []);
});

test('stores valid generated words and rejects duplicates', async () => {
  const store = new WordStore({ seed: false });
  const service = new VocabularyGenerationService({
    store,
    liteLLMClient: {
      generateVocabulary: async () => JSON.stringify({ items: [wordInput(), wordInput()] })
    },
    logger: { warn() {} }
  });

  const accepted = await service.generateAndStore({ limit: 2 });

  assert.equal(accepted.length, 1);
  assert.equal(store.findNewWords({ limit: 10 }).length, 1);
});

test('rejects missing required fields', async () => {
  const store = new WordStore({ seed: false });
  const service = new VocabularyGenerationService({
    store,
    liteLLMClient: {
      generateVocabulary: async () => JSON.stringify({ items: [{ term: 'broken' }] })
    },
    logger: { warn() {} }
  });

  const accepted = await service.generateAndStore({ limit: 1 });

  assert.equal(accepted.length, 0);
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
