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
