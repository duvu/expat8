import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { initialSrsMemory, nextSrsMemory, replaySrsState, srsDueAtMs, srsStatus } from '../src/domain/srs.js';

const vectors = JSON.parse(readFileSync(new URL('../../contracts/srs_vectors.json', import.meta.url), 'utf8'));

test('scheduler reproduces every shared SRS vector (mobile replays the same file)', () => {
  for (const { name, steps } of vectors.cases) {
    let memory = initialSrsMemory();
    for (const step of steps) {
      memory = nextSrsMemory(memory, step.rating);
      assert.deepEqual(
        {
          reps: memory.reps,
          lapses: memory.lapses,
          ease: memory.ease,
          interval_days: memory.intervalDays,
          status: srsStatus(memory),
          due_at: new Date(srsDueAtMs(memory, Date.parse(step.rated_at))).toISOString()
        },
        {
          reps: step.reps,
          lapses: step.lapses,
          ease: step.ease,
          interval_days: step.interval_days,
          status: step.status,
          due_at: step.due_at
        },
        `${name} after ${step.rating} at ${step.rated_at}`
      );
    }
  }
});

test('easy words come back for review instead of disappearing', () => {
  const state = replaySrsState([{ rating: 'easy', occurred_at: '2026-01-01T00:00:00Z', client_event_id: 'a' }]);
  assert.equal(state.status, 'review');
  assert.equal(state.next_review_at, '2026-01-03T00:00:00.000Z');
});

test('replay is order-independent, so late offline events converge', () => {
  const events = [
    { rating: 'easy', occurred_at: '2026-01-01T00:00:00Z', client_event_id: 'a' },
    { rating: 'too_hard', occurred_at: '2026-01-03T00:00:00+00:00', client_event_id: 'b' },
    { rating: 'hard', occurred_at: new Date('2026-01-03T00:10:00Z'), client_event_id: 'c' }
  ];
  const inOrder = replaySrsState(events);
  // The phone that was offline uploads its older event last.
  const lateArrival = replaySrsState([events[2], events[1], events[0]]);
  assert.deepEqual(lateArrival, inOrder);
  assert.equal(inOrder.lapses, 1);
  assert.equal(inOrder.last_rating, 'hard');
  assert.equal(inOrder.review_count, 3);
});

test('events with unknown ratings are skipped and no events means no state', () => {
  assert.equal(replaySrsState([]), null);
  const state = replaySrsState([
    { rating: 'easy', occurred_at: '2026-01-01T00:00:00Z', client_event_id: 'a' },
    { rating: 'remembered', occurred_at: '2026-01-02T00:00:00Z', client_event_id: 'b' }
  ]);
  assert.equal(state.last_rating, 'easy');
  assert.equal(state.review_count, 1);
});
