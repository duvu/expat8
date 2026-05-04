import assert from 'node:assert/strict';
import test from 'node:test';

import { WordStore } from '../src/word_store.js';

test('prevents duplicate words by language and normalized term', () => {
  const store = new WordStore({ seed: false });

  const first = store.insertWord(wordInput({ term: 'Reliable' }));
  const second = store.insertWord(wordInput({ term: ' reliable ' }));

  assert.equal(first.inserted, true);
  assert.equal(second.inserted, false);
  assert.equal(first.word.id, second.word.id);
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
        rating: 'remembered',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  };

  const first = store.syncStudyEvents(payload);
  const second = store.syncStudyEvents(payload);

  assert.deepEqual(first.accepted_event_ids, ['evt_1']);
  assert.deepEqual(second.accepted_event_ids, ['evt_1']);
  assert.equal(store.studyEventsByClientId.size, 1);
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
