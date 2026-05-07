import assert from 'node:assert/strict';
import test from 'node:test';

import { LiteLLMClient } from '../src/litellm_client.js';

test('builds CEFR-oriented prompt for English generation', async () => {
  let requestBody = null;
  const client = new LiteLLMClient({
    baseUrl: 'http://litellm.local',
    model: 'fake-model',
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return {
        ok: true,
        status: 200,
        json: async () => ({ choices: [{ message: { content: '[]' } }] })
      };
    },
    logger: { debug() {}, error() {} }
  });

  await client.generateVocabulary({
    sourceLanguage: 'vi',
    targetLanguage: 'en',
    limit: 2,
    difficultyLevel: 'B1'
  });

  const userPrompt = requestBody.messages.find((message) => message.role === 'user').content;
  assert.match(userPrompt, /Target proficiency scale is CEFR/i);
  assert.match(userPrompt, /difficulty is one of A1\/A2\/B1\/B2\/C1\/C2/i);
});

test('builds HSK-oriented prompt for Chinese generation', async () => {
  let requestBody = null;
  const client = new LiteLLMClient({
    baseUrl: 'http://litellm.local',
    model: 'fake-model',
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return {
        ok: true,
        status: 200,
        json: async () => ({ choices: [{ message: { content: '[]' } }] })
      };
    },
    logger: { debug() {}, error() {} }
  });

  await client.generateVocabulary({
    sourceLanguage: 'vi',
    targetLanguage: 'zh',
    limit: 2,
    difficultyLevel: 'hsk2'
  });

  const userPrompt = requestBody.messages.find((message) => message.role === 'user').content;
  assert.match(userPrompt, /Target proficiency scale is HSK/i);
  assert.match(userPrompt, /difficulty is one of HSK1\/HSK2\/HSK3\/HSK4\/HSK5\/HSK6/i);
  assert.match(userPrompt, /vietnamese_pronunciation MUST contain pinyin-style romanization/i);
});
