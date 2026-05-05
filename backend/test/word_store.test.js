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

test('filters words by proficiency level with fallback order', () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_a2', term: 'basic', difficulty: 'A2' }));
  store.insertWord(wordInput({ id: 'word_b2', term: 'refine', difficulty: 'B2' }));
  store.insertWord(wordInput({ id: 'word_c1', term: 'articulate', difficulty: 'C1' }));

  const words = store.findNewWords({
    targetLanguage: 'en',
    limit: 1,
    proficiencyLevel: 'B1'
  });

  assert.deepEqual(words.map((word) => word.id), ['word_b2']);
});

test('uses device proficiency when word feed omits explicit level', () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_a1', term: 'basic', difficulty: 'A1' }));
  store.insertWord(wordInput({ id: 'word_a2', term: 'bridge', difficulty: 'A2' }));

  for (let index = 0; index < 5; index += 1) {
    store.recordStudyEvent({
      deviceId: 'device_query',
      event: {
        client_event_id: `evt_query_${index + 1}`,
        server_word_id: 'word_a1',
        local_word_id: 'local_1',
        rating: 'too_easy',
        occurred_at: `2026-05-04T10:38:0${index}.000Z`
      }
    });
  }

  const words = store.findNewWords({
    targetLanguage: 'en',
    limit: 1,
    deviceId: 'device_query'
  });

  assert.deepEqual(words.map((word) => word.id), ['word_a2']);
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
