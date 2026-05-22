import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { VocabularyGenerationService } from '../src/generation_service.js';
import { SubmittedWordWorker } from '../src/submitted_word_worker.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('user-submitted words API resolves immediately and reuses ready submissions', async () => {
  const store = new WordStore({ seed: false });
  const generationService = {
    async generateSubmittedWord({ term, targetLanguage }) {
      const { word } = store.insertWord({
        term,
        language: targetLanguage,
        meaning_vi: 'bướng bỉnh',
        part_of_speech: 'adjective',
        ipa: '/ˈstʌbərn/',
        vietnamese_pronunciation: 'stuh-burn',
        example: 'He is stubborn about changing his plan.',
        example_vi: 'Anh ay rat buong binh ve viec doi ke hoach.',
        difficulty: 'B1',
        topics: ['people'],
        explanation: '',
        generation_source: 'user_submission'
      });
      return { word, resolutionType: 'generated_word' };
    }
  };
  const server = http.createServer(createApp({ store, generationService, config: loadTestConfig() }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const createUrl = `${baseUrl}/v1/user-submitted-words`;
    const payload = {
      device_id: 'anonymous_device_1',
      term: 'stubborn',
      target_language: 'en'
    };

    const createdResponse = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(payload)
      })
    );
    assert.equal(createdResponse.status, 201);
    const created = await createdResponse.json();
    assert.equal(created.status, 'ready');
    assert.equal(created.resolution_type, 'generated_word');
    assert.equal(created.resolved_word.term, 'stubborn');
    assert.equal(created.submitted_term, 'stubborn');
    assert.equal(created.target_language, 'en');

    const duplicateResponse = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(payload)
      })
    );
    assert.equal(duplicateResponse.status, 200);
    const duplicate = await duplicateResponse.json();
    assert.equal(duplicate.id, created.id);
    assert.equal(duplicate.status, 'ready');

    const listUrl = `${baseUrl}/v1/user-submitted-words?device_id=anonymous_device_1&limit=10`;
    const list = await fetchJson(listUrl);
    assert.equal(list.items.length, 1);
    assert.equal(list.items[0].id, created.id);
    assert.equal(list.items[0].status, 'ready');
  } finally {
    server.close();
  }
});

test('user-submitted words API returns existing canonical word immediately', async () => {
  const store = new WordStore({ seed: false });
  store.insertWord({
    term: 'reliable',
    language: 'en',
    meaning_vi: 'dang tin cay',
    part_of_speech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamese_pronunciation: 'ri-lai-uh-bol',
    example: 'She is a reliable teammate.',
    example_vi: 'Co ay la mot dong doi dang tin cay.',
    difficulty: 'B1',
    topics: ['work', 'people'],
    explanation: '',
    generation_source: 'seed'
  });
  const server = http.createServer(createApp({ store, generationService: null, config: loadTestConfig() }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const createUrl = `${baseUrl}/v1/user-submitted-words`;
    const response = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          device_id: 'anonymous_device_2',
          term: 'reliable',
          target_language: 'en'
        })
      })
    );
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.status, 'ready');
    assert.equal(body.resolution_type, 'existing_word');
    assert.equal(body.resolved_word.term, 'reliable');
  } finally {
    server.close();
  }
});

test('user-submitted words API validates body and optional session', async () => {
  const store = new WordStore({ seed: false });
  const generationService = {
    async generateSubmittedWord({ term, targetLanguage }) {
      const { word } = store.insertWord({
        term,
        language: targetLanguage,
        meaning_vi: 'cẩn thận',
        part_of_speech: 'adjective',
        ipa: '/ˈkerfəl/',
        vietnamese_pronunciation: 'ke-rồ-phồl',
        example: 'Be careful with that glass.',
        example_vi: 'Hay can than voi cai ly do.',
        difficulty: 'A2',
        topics: ['daily'],
        explanation: '',
        generation_source: 'user_submission'
      });
      return { word, resolutionType: 'generated_word' };
    }
  };
  const registered = store.registerUser({
    identifier: 'submitted@example.com',
    password: 'correct-password',
    deviceId: 'device-auth'
  });
  const server = http.createServer(createApp({ store, generationService, config: loadTestConfig() }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const createUrl = `${baseUrl}/v1/user-submitted-words`;

    const invalidLanguage = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ device_id: 'device-auth', term: 'hola', target_language: 'xx' })
      })
    );
    assert.equal(invalidLanguage.status, 400);

    const invalidSession = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer invalid-session-token'
        },
        body: JSON.stringify({ device_id: 'device-auth', term: 'hello', target_language: 'en' })
      })
    );
    assert.equal(invalidSession.status, 401);

    const signedIn = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${registered.sessionToken}`
        },
        body: JSON.stringify({ device_id: 'device-auth', term: 'careful', target_language: 'en' })
      })
    );
    assert.equal(signedIn.status, 201);
    const body = await signedIn.json();
    assert.equal(body.status, 'ready');
  } finally {
    server.close();
  }
});

test('user-submitted words API returns terminal failed submission when immediate generation fails', async () => {
  const store = new WordStore({ seed: false });
  const generationService = {
    async generateSubmittedWord() {
      throw new Error('llm_unavailable');
    }
  };
  const server = http.createServer(createApp({ store, generationService, config: loadTestConfig() }));
  await listen(server);
  try {
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const createUrl = `${baseUrl}/v1/user-submitted-words`;
    const response = await fetch(
      createUrl,
      signedFetchOptions(createUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          device_id: 'anonymous_device_4',
          term: 'hesitate',
          target_language: 'en'
        })
      })
    );
    assert.equal(response.status, 201);
    const body = await response.json();
    assert.equal(body.status, 'failed');
    assert.match(body.failure_reason, /llm_unavailable/);

    const listUrl = `${baseUrl}/v1/user-submitted-words?device_id=anonymous_device_4&limit=10`;
    const list = await fetchJson(listUrl);
    assert.equal(list.items.length, 1);
    assert.equal(list.items[0].status, 'failed');
  } finally {
    server.close();
  }
});

test('submitted vocabulary generation stores the requested canonical word', async () => {
  const store = new WordStore({ seed: false });
  const generationService = new VocabularyGenerationService({
    liteLLMClient: {
      async generateSubmittedVocabulary() {
        return JSON.stringify([
          {
            term: 'stubborn',
            language: 'en',
            meaning_vi: 'bướng bỉnh',
            part_of_speech: 'adjective',
            ipa: '/ˈstʌbərn/',
            vietnamese_pronunciation: 'stuh-burn',
            example: 'He is stubborn about changing his plan.',
            example_vi: 'Anh ay rat buong binh ve viec doi ke hoach.',
            difficulty: 'B1',
            topics: ['people'],
            entry_type: 'word',
            blank_word: null,
            explanation: ''
          }
        ]);
      }
    },
    store
  });

  const result = await generationService.generateSubmittedWord({ term: 'stubborn', targetLanguage: 'en' });
  assert.equal(result.word.term, 'stubborn');
  assert.equal(result.word.generation_source, 'user_submission');
  assert.equal(result.resolutionType, 'generated_word');
});

test('submitted word worker retries then fails after max attempts', async () => {
  const store = new WordStore({ seed: false });
  const created = await store.createUserSubmittedWord({
    deviceId: 'anonymous_device_3',
    term: 'hesitate',
    language: 'en'
  });
  assert.equal(created.submission.status, 'queued');

  const worker = new SubmittedWordWorker({
    store,
    generationService: {
      async generateSubmittedWord() {
        throw new Error('llm_unavailable');
      }
    },
    maxAttempts: 2
  });

  const first = await worker.runOnce();
  assert.equal(first.retry_scheduled, true);
  const firstState = store.getUserSubmittedWordById({ submissionId: created.submission.id });
  assert.equal(firstState.status, 'queued');

  const second = await worker.runOnce();
  assert.equal(second.dead_lettered, 1);
  const secondState = store.getUserSubmittedWordById({ submissionId: created.submission.id });
  assert.equal(secondState.status, 'failed');
  assert.match(secondState.failure_reason, /llm_unavailable/);
});

async function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, signedFetchOptions(url, options));
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json();
}
