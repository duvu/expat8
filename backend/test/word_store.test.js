import assert from 'node:assert/strict';
import test from 'node:test';

import { WordStore, normalizeSpeakingEvent, isSpeakingEvent, SPEAKING_EVENT_TYPES } from '../src/word_store.js';

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
  assert.deepEqual(second.accepted_event_ids, []);
  assert.deepEqual(second.duplicates, ['evt_1']);
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
      event_id: null,
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

// ---- Speaking event tests ----

test('SPEAKING_EVENT_TYPES includes speaking_drill_completed', () => {
  assert.ok(SPEAKING_EVENT_TYPES.includes('speaking_drill_completed'));
  assert.equal(SPEAKING_EVENT_TYPES.length, 8);
});

test('isSpeakingEvent returns true for all speaking event types', () => {
  for (const type of SPEAKING_EVENT_TYPES) {
    assert.ok(isSpeakingEvent({ event_type: type }), `expected isSpeakingEvent for ${type}`);
  }
  assert.equal(isSpeakingEvent({ event_type: 'easy' }), false);
  assert.equal(isSpeakingEvent({ event_type: 'speaking_magic_score' }), false);
});

test('normalizeSpeakingEvent accepts all 8 speaking event types', () => {
  const base = {
    attempt_id: 'attempt_x',
    occurred_at: '2026-05-10T10:00:00.000Z'
  };
  for (const type of SPEAKING_EVENT_TYPES) {
    let event = { event_type: type, ...base };
    if (type === 'speaking_drill_completed') {
      event = { ...event, prompts_attempted: 5, total_duration_ms: 180000 };
    }
    const normalized = normalizeSpeakingEvent({ deviceId: 'device_test', event });
    assert.equal(normalized.event_type, type);
  }
});

test('normalizeSpeakingEvent rejects unknown speaking event type', () => {
  assert.throws(
    () => normalizeSpeakingEvent({ deviceId: 'd', event: { event_type: 'speaking_magic_score', attempt_id: 'a', occurred_at: '2026-01-01T00:00:00Z' } }),
    { message: 'invalid_speaking_event_type' }
  );
});

test('normalizeSpeakingEvent rejects forbidden audio fields', () => {
  assert.throws(
    () => normalizeSpeakingEvent({ deviceId: 'd', event: { event_type: 'speaking_recorded', attempt_id: 'a', occurred_at: '2026-01-01T00:00:00Z', local_audio_path: '/tmp/x.m4a' } }),
    { message: 'forbidden_audio_field' }
  );
});

test('normalizeSpeakingEvent requires prompts_attempted and total_duration_ms for drill_completed', () => {
  const base = { event_type: 'speaking_drill_completed', attempt_id: 'sess_1', occurred_at: '2026-05-10T10:00:00Z' };
  assert.throws(
    () => normalizeSpeakingEvent({ deviceId: 'd', event: { ...base, total_duration_ms: 180000 } }),
    { message: 'missing_required_field' }
  );
  assert.throws(
    () => normalizeSpeakingEvent({ deviceId: 'd', event: { ...base, prompts_attempted: 5 } }),
    { message: 'missing_required_field' }
  );
  const ok = normalizeSpeakingEvent({ deviceId: 'd', event: { ...base, prompts_attempted: 5, total_duration_ms: 180000 } });
  assert.equal(ok.prompts_attempted, 5);
  assert.equal(ok.total_duration_ms, 180000);
});

test('speaking events do not affect proficiency level', () => {
  const store = new WordStore({ seed: false });
  store.insertWord(wordInput({ id: 'word_sp1', term: 'hello' }));

  // Sync 4 easy ratings to nearly reach level-up threshold
  for (let i = 0; i < 4; i++) {
    store.syncStudyEvents({
      deviceId: 'device_prof_isolation',
      language: 'en',
      userId: null,
      events: [{
        client_event_id: `easy_${i}`,
        server_word_id: 'word_sp1',
        rating: 'too_easy',
        occurred_at: `2026-05-10T10:0${i}:00.000Z`
      }]
    });
  }

  const before = store.getProficiency({ deviceId: 'device_prof_isolation', language: 'en' });

  // Sync 10 speaking events of all types
  const speakingEvents = [
    { client_event_id: 'sp_viewed', event_type: 'speaking_prompt_viewed', speaking: { attempt_id: 'a1', prompt_id: 'p1' } },
    { client_event_id: 'sp_played', event_type: 'speaking_sample_played', speaking: { attempt_id: 'a1', prompt_id: 'p1' } },
    { client_event_id: 'sp_recorded', event_type: 'speaking_recorded', speaking: { attempt_id: 'a1', duration_ms: 3000, retry_count: 0 } },
    { client_event_id: 'sp_retried', event_type: 'speaking_retried', speaking: { attempt_id: 'a1', retry_count: 1 } },
    { client_event_id: 'sp_rated_clear', event_type: 'speaking_self_rated_clear', speaking: { attempt_id: 'a1', self_rating: 'clear' } },
    { client_event_id: 'sp_rated_hes', event_type: 'speaking_self_rated_hesitated', speaking: { attempt_id: 'a2', self_rating: 'hesitated' } },
    { client_event_id: 'sp_rated_cnt', event_type: 'speaking_self_rated_could_not_say', speaking: { attempt_id: 'a3', self_rating: 'could_not_say' } },
    { client_event_id: 'sp_drill', event_type: 'speaking_drill_completed', speaking: { attempt_id: 'sess1', prompts_attempted: 5, prompts_completed: 4, total_duration_ms: 180000 } },
  ].map((e) => ({ ...e, occurred_at: '2026-05-10T11:00:00.000Z', language: 'en' }));

  store.syncStudyEvents({
    deviceId: 'device_prof_isolation',
    language: 'en',
    userId: null,
    events: speakingEvents
  });

  const after = store.getProficiency({ deviceId: 'device_prof_isolation', language: 'en' });
  assert.equal(before.level, after.level, 'speaking events must not change proficiency level');
  assert.equal(store.speakingEventsByKey.size, 8);
  assert.equal(store.studyEventsByClientId.size, 4); // only non-speaking events
});

test('getSpeakingSummary returns retry_rate, drill_sessions_completed, first_recording_at', () => {
  const store = new WordStore({ seed: false });

  // New device: zero state
  const empty = store.getSpeakingSummary({ deviceId: 'device_summary_new', language: 'en' });
  assert.equal(empty.spoken_sentence_count, 0);
  assert.equal(empty.retry_rate, 0);
  assert.equal(empty.drill_sessions_completed, 0);
  assert.equal(empty.first_recording_at, null);

  // Seed speaking events
  const events = [
    { client_event_id: 'sum_rec1', event_type: 'speaking_recorded', speaking: { attempt_id: 'a1', duration_ms: 3000, retry_count: 0 } },
    { client_event_id: 'sum_rec2', event_type: 'speaking_recorded', speaking: { attempt_id: 'a2', duration_ms: 4000, retry_count: 0 } },
    { client_event_id: 'sum_retry', event_type: 'speaking_retried', speaking: { attempt_id: 'a2', retry_count: 1 } },
    { client_event_id: 'sum_drill', event_type: 'speaking_drill_completed', speaking: { attempt_id: 'sess1', prompts_attempted: 5, total_duration_ms: 170000 } },
  ].map((e) => ({ ...e, occurred_at: '2026-05-10T12:00:00.000Z', language: 'en' }));

  store.syncStudyEvents({ deviceId: 'device_summary_new', language: 'en', userId: null, events });

  const summary = store.getSpeakingSummary({ deviceId: 'device_summary_new', language: 'en', weekStart: '2026-05-05' });
  assert.equal(summary.spoken_sentence_count, 2);
  assert.equal(summary.retry_count, 1);
  assert.equal(summary.retry_rate, 0.5); // 1 retry / 2 recordings
  assert.equal(summary.drill_sessions_completed, 1);
  assert.equal(summary.first_recording_at, '2026-05-10T12:00:00.000Z');
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
