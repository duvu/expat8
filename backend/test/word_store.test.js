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
        rating: 'easy',
        occurred_at: '2026-05-04T10:30:00.000Z'
      }
    ]
  };

  const first = store.syncStudyEvents(payload);
  const second = store.syncStudyEvents(payload);

  assert.deepEqual(first.accepted_event_ids, ['evt_1']);
  assert.deepEqual(second.accepted_event_ids, ['evt_1']);
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
    wordIds: [
      ...Array.from({ length: 1005 }, (_, index) => `cache_${index}`),
      'unknown_word'
    ],
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
  assert.deepEqual(first.target_mix, { new: 10, review: 0 });
  assert.deepEqual(first.actual_mix, { new: 10, review: 0 });
  assert.equal(store.cachedWordIdsFor({ deviceId: 'anonymous_batch' }).size, 12);
  assert.equal(second.items.length, 2);
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

  assert.deepEqual(result.items.map((card) => card.word.id), ['word_seen']);
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
