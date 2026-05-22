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
      generateVocabulary: async ({ difficultyLevel }) =>
        JSON.stringify({
          items: [wordInput({ difficulty: difficultyLevel }), wordInput({ difficulty: difficultyLevel })]
        })
    },
    logger: { warn() {} }
  });

  const accepted = await service.generateAndStore({ limit: 2 });

  assert.equal(accepted.length, 1);
  assert.equal(store.countUsableWords(), 1);
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

test('retries generation with avoided terms when the first result is a duplicate', async () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ term: 'Accomplish' }));

  const attempts = [];
  const service = new VocabularyGenerationService({
    store,
    liteLLMClient: {
      generateVocabulary: async ({ avoidTerms }) => {
        attempts.push(avoidTerms);
        if (attempts.length === 1) {
          return JSON.stringify({ items: [wordInput({ term: 'Accomplish' })] });
        }
        return JSON.stringify({
          items: [wordInput({ term: 'Opportunity', example: 'This opportunity could change your life.' })]
        });
      }
    },
    logger: { warn() {} }
  });

  const accepted = await service.generateAndStore({ limit: 1, avoidTerms: ['Accomplish'] });

  assert.equal(accepted.length, 1);
  assert.equal(accepted[0].term, 'Opportunity');
  assert.deepEqual(attempts[0], ['accomplish']);
  assert.deepEqual(attempts[1], ['accomplish']);
});

test('passes target CEFR level through generation flow', async () => {
  const store = new WordStore({ seed: false });
  let requestedDifficultyLevel = null;
  const service = new VocabularyGenerationService({
    store,
    liteLLMClient: {
      generateVocabulary: async ({ difficultyLevel }) => {
        requestedDifficultyLevel = difficultyLevel;
        return JSON.stringify({ items: [wordInput({ difficulty: 'A2' })] });
      }
    },
    logger: { warn() {} }
  });

  const accepted = await service.generateAndStore({ limit: 1, difficultyLevel: 'A2' });

  assert.equal(requestedDifficultyLevel, 'A2');
  assert.equal(accepted[0].difficulty, 'A2');
});

test('rejects Chinese generation items with non-HSK difficulty values', async () => {
  const store = new WordStore({ seed: false });
  const service = new VocabularyGenerationService({
    store,
    liteLLMClient: {
      generateVocabulary: async () =>
        JSON.stringify({
          items: [
            wordInput({
              language: 'zh',
              term: 'xuexi',
              difficulty: 'B1',
              vietnamese_pronunciation: 'xue xi',
              ipa: ''
            })
          ]
        })
    },
    logger: { warn() {} }
  });

  const accepted = await service.generateAndStore({
    limit: 1,
    targetLanguage: 'zh',
    difficultyLevel: 'HSK2'
  });

  assert.equal(accepted.length, 0);
});

test('rejects Chinese generation items with invalid pronunciation metadata', async () => {
  const store = new WordStore({ seed: false });
  const warnings = [];
  const service = new VocabularyGenerationService({
    store,
    liteLLMClient: {
      generateVocabulary: async () =>
        JSON.stringify({
          items: [
            wordInput({
              language: 'zh',
              term: 'xuexi',
              difficulty: 'HSK2',
              vietnamese_pronunciation: '1234',
              ipa: ''
            })
          ]
        })
    },
    logger: {
      warn(event, context) {
        warnings.push({ event, context });
      }
    }
  });

  const accepted = await service.generateAndStore({
    limit: 1,
    targetLanguage: 'zh',
    difficultyLevel: 'HSK2'
  });

  assert.equal(accepted.length, 0);
  assert.deepEqual(warnings[0], {
    event: 'ai_generation_item_rejected',
    context: {
      reason: 'invalid_chinese_pinyin',
      term: 'xuexi'
    }
  });
});

test('stores Chinese generation item with pinyin and no IPA', async () => {
  const store = new WordStore({ seed: false });
  const warnings = [];
  const service = new VocabularyGenerationService({
    store,
    liteLLMClient: {
      generateVocabulary: async () =>
        JSON.stringify({
          items: [
            wordInput({
              language: 'zh',
              term: '资格',
              difficulty: 'HSK2',
              vietnamese_pronunciation: 'zi ge',
              ipa: '',
              example: '我有这个资格。'
            })
          ]
        })
    },
    logger: {
      warn(event, context) {
        warnings.push({ event, context });
      }
    }
  });

  const accepted = await service.generateAndStore({
    limit: 1,
    targetLanguage: 'zh',
    difficultyLevel: 'HSK2'
  });

  assert.equal(accepted.length, 1);
  assert.equal(accepted[0].term, '资格');
  assert.deepEqual(warnings, []);
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
