import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('smoke: new word retrieval, local save, rating queue, and backend sync', async (t) => {
  const backendStore = new WordStore();
  const server = http.createServer(
    createApp({
      store: backendStore,
      generationService: null,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const localClient = new SmokeLocalClient({ baseUrl, deviceId: 'device_smoke' });

  const word = await localClient.fetchNewWord();
  localClient.saveWord(word);
  localClient.rateWord(word, 'easy');
  await localClient.sync();

  assert.equal(localClient.words.size, 1);
  assert.equal(localClient.syncQueue.length, 0);
  assert.equal(backendStore.studyEventsByClientId.size, 1);
});

test('e2e: english CEFR progression reaches A2 after five too_easy ratings', async (t) => {
  const backendStore = new WordStore({ seed: false });
  backendStore.insertWord(wordInput({
    id: 'word_en_1',
    term: 'reliable',
    language: 'en',
    difficulty: 'A1'
  }));
  const server = http.createServer(
    createApp({
      store: backendStore,
      generationService: null,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const deviceId = 'device_e2e_en';

  for (let index = 0; index < 5; index += 1) {
    const response = await fetchJson(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: deviceId,
        language: 'en',
        client_event_id: `evt_en_progress_${index + 1}`,
        server_word_id: 'word_en_1',
        local_word_id: `local_en_${index + 1}`,
        rating: 'too_easy',
        occurred_at: `2026-05-06T10:2${index}:00.000Z`
      })
    });
    assert.equal(response.success, true);
  }

  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=${deviceId}&language=en`);
  assert.equal(proficiency.scale, 'cefr');
  assert.equal(proficiency.level, 'A2');
  assert.equal(proficiency.level_index, 1);
});

test('e2e: chinese HSK progression reaches HSK2 and drives level-aware selection', async (t) => {
  const backendStore = new WordStore({ seed: false });
  backendStore.insertWord(wordInput({
    id: 'word_zh_1',
    term: '你好',
    language: 'zh',
    difficulty: 'HSK1',
    ipa: '',
    vietnamese_pronunciation: 'ni hao'
  }));
  backendStore.insertWord(wordInput({
    id: 'word_zh_2',
    term: '学习',
    language: 'zh',
    difficulty: 'HSK2',
    ipa: '',
    vietnamese_pronunciation: 'xue xi'
  }));
  const server = http.createServer(
    createApp({
      store: backendStore,
      generationService: null,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const deviceId = 'device_e2e_zh';

  for (let index = 0; index < 5; index += 1) {
    const response = await fetchJson(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: deviceId,
        language: 'zh',
        client_event_id: `evt_zh_progress_${index + 1}`,
        server_word_id: 'word_zh_1',
        local_word_id: `local_zh_${index + 1}`,
        rating: 'too_easy',
        occurred_at: `2026-05-06T10:3${index}:00.000Z`
      })
    });
    assert.equal(response.success, true);
  }

  const proficiency = await fetchJson(`${baseUrl}/v1/proficiency?device_id=${deviceId}&language=zh`);
  assert.equal(proficiency.scale, 'hsk');
  assert.equal(proficiency.level, 'HSK2');
  assert.equal(proficiency.level_index, 1);

  const next = await fetchJson(
    `${baseUrl}/v1/words/next?limit=1&target_language=zh&device_id=${deviceId}`
  );
  assert.equal(next.items.length, 1);
  assert.equal(next.items[0].server_word_id, 'word_zh_2');
});

test('e2e: proficiency stays isolated by language for the same device', async (t) => {
  const backendStore = new WordStore({ seed: false });
  backendStore.insertWord(wordInput({ id: 'word_en_isolation', term: 'focus', language: 'en', difficulty: 'A1' }));
  backendStore.insertWord(wordInput({
    id: 'word_zh_isolation',
    term: '专注',
    language: 'zh',
    difficulty: 'HSK1',
    ipa: '',
    vietnamese_pronunciation: 'zhuan zhu'
  }));
  const server = http.createServer(
    createApp({
      store: backendStore,
      generationService: null,
      config: loadTestConfig()
    })
  );
  await listen(server);
  t.after(() => server.close());

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const deviceId = 'device_e2e_isolation';

  for (let index = 0; index < 5; index += 1) {
    await fetchJson(`${baseUrl}/v1/study-events`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: deviceId,
        language: 'en',
        client_event_id: `evt_isolation_en_${index + 1}`,
        server_word_id: 'word_en_isolation',
        local_word_id: `local_iso_en_${index + 1}`,
        rating: 'too_easy',
        occurred_at: `2026-05-06T10:4${index}:00.000Z`
      })
    });
  }

  const english = await fetchJson(`${baseUrl}/v1/proficiency?device_id=${deviceId}&language=en`);
  const chinese = await fetchJson(`${baseUrl}/v1/proficiency?device_id=${deviceId}&language=zh`);

  assert.equal(english.scale, 'cefr');
  assert.equal(english.level, 'A2');
  assert.equal(chinese.scale, 'hsk');
  assert.equal(chinese.level, 'HSK1');
});

class SmokeLocalClient {
  constructor({ baseUrl, deviceId }) {
    this.baseUrl = baseUrl;
    this.deviceId = deviceId;
    this.words = new Map();
    this.syncQueue = [];
  }

  async fetchNewWord() {
    const url = `${this.baseUrl}/v1/learning/cards`;
    const options = {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: this.deviceId,
        target_language: 'en',
        limit: 10,
        card_mode: 'new'
      })
    };
    const response = await fetch(url, signedFetchOptions(url, options));
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.ok(body.items.length >= 1);
    return body.items[0];
  }

  saveWord(word) {
    this.words.set(word.server_word_id, {
      ...word,
      status: 'new',
      last_seen_at: new Date().toISOString()
    });
  }

  rateWord(word, rating) {
    this.syncQueue.push({
      client_event_id: 'evt_smoke_1',
      server_word_id: word.server_word_id,
      local_word_id: word.server_word_id,
      rating,
      occurred_at: '2026-05-04T10:30:00.000Z'
    });
  }

  async sync() {
    const url = `${this.baseUrl}/v1/study-events/sync`;
    const options = {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_id: this.deviceId,
        events: this.syncQueue
      })
    };
    const response = await fetch(url, signedFetchOptions(url, options));
    assert.equal(response.status, 200);
    const body = await response.json();
    this.syncQueue = this.syncQueue.filter(
      (event) => !body.accepted_event_ids.includes(event.client_event_id)
    );
  }
}

function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, signedFetchOptions(url, options));
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  return body;
}

function wordInput(overrides = {}) {
  return {
    id: overrides.id,
    term: overrides.term ?? 'reliable',
    language: overrides.language ?? 'en',
    meaning_vi: overrides.meaning_vi ?? 'dang tin cay',
    part_of_speech: overrides.part_of_speech ?? 'adjective',
    ipa: overrides.ipa ?? '/rɪˈlaɪəbl/',
    vietnamese_pronunciation: overrides.vietnamese_pronunciation ?? 'ri-lai-uh-bol',
    example: overrides.example ?? 'She is a reliable teammate.',
    example_vi: overrides.example_vi ?? 'Co ay la dong doi dang tin cay.',
    difficulty: overrides.difficulty ?? 'A1',
    topics: overrides.topics ?? ['work'],
    created_at: overrides.created_at ?? '2026-05-01T00:00:00.000Z',
    updated_at: overrides.updated_at ?? '2026-05-01T00:00:00.000Z'
  };
}
