import assert from 'node:assert/strict';
import test from 'node:test';

import { InMemoryRateLimiter } from '../src/rate_limit.js';

test('rate limiter rejects once the window cap is reached and recovers after the window', () => {
  const limiter = new InMemoryRateLimiter({ windowMs: 1_000, maxRequests: 2 });

  assert.equal(limiter.check('k', 0).allowed, true);
  assert.equal(limiter.check('k', 10).allowed, true);
  assert.equal(limiter.check('k', 20).allowed, false);
  assert.equal(limiter.check('other', 20).allowed, true);
  assert.equal(limiter.check('k', 1_001).allowed, true);
});

test('rate limiter prunes expired buckets during normal checks', () => {
  const limiter = new InMemoryRateLimiter({ windowMs: 1_000, maxRequests: 5 });

  for (let i = 0; i < 100; i += 1) {
    limiter.check(`key-${i}`, 10);
  }
  assert.equal(limiter._buckets.size, 100);

  limiter.check('fresh', 2_000);
  assert.deepEqual([...limiter._buckets.keys()], ['fresh']);
});
