import assert from 'node:assert/strict';
import test from 'node:test';

import { LlmRateLimiter, parseRetryAfterMs } from '../src/llm_rate_limiter.js';

function fakeClock() {
  const clock = { time: 1_000_000, sleeps: [] };
  clock.now = () => clock.time;
  clock.sleep = async (ms) => {
    clock.sleeps.push(ms);
    clock.time += ms;
  };
  return clock;
}

const ok = () => ({ status: 200, headers: new Headers() });

test('spaces request starts by the minimum interval', async () => {
  const clock = fakeClock();
  const limiter = new LlmRateLimiter({ minIntervalMs: 5000 }, { sleep: clock.sleep, now: clock.now });
  await limiter.run(async () => ok());
  await limiter.run(async () => ok());
  assert.deepEqual(clock.sleeps, [5000]);
});

test('retries 429 after honouring Retry-After and reports the final response', async () => {
  const clock = fakeClock();
  const limiter = new LlmRateLimiter({ minIntervalMs: 0 }, { sleep: clock.sleep, now: clock.now, logger: {} });
  let calls = 0;
  const response = await limiter.run(async () => {
    calls += 1;
    return calls === 1 ? { status: 429, headers: new Headers({ 'retry-after': '40' }) } : ok();
  });
  assert.equal(response.status, 200);
  assert.equal(calls, 2);
  assert.ok(clock.sleeps[0] >= 40_000);
});

test('gives up with the throttled response after maxRetries', async () => {
  const clock = fakeClock();
  const limiter = new LlmRateLimiter(
    { minIntervalMs: 0, maxRetries: 2, backoffBaseMs: 10 },
    { sleep: clock.sleep, now: clock.now, logger: {} }
  );
  let calls = 0;
  const response = await limiter.run(async () => {
    calls += 1;
    return { status: 429, headers: new Headers() };
  });
  assert.equal(response.status, 429);
  assert.equal(calls, 3);
});

test('waits for the hourly budget to free up', async () => {
  const clock = fakeClock();
  const limiter = new LlmRateLimiter(
    { minIntervalMs: 0, maxRequestsPerHour: 2 },
    { sleep: clock.sleep, now: clock.now }
  );
  await limiter.run(async () => ok());
  await limiter.run(async () => ok());
  assert.equal(limiter.remainingHourlyBudget(), 0);
  await limiter.run(async () => ok());
  assert.ok(clock.sleeps.at(-1) >= 3_599_000);
});

test('runs one request at a time by default', async () => {
  const limiter = new LlmRateLimiter({ minIntervalMs: 0 });
  let active = 0;
  let peak = 0;
  const task = async () => {
    active += 1;
    peak = Math.max(peak, active);
    await new Promise((resolve) => setTimeout(resolve, 5));
    active -= 1;
    return ok();
  };
  await Promise.all([limiter.run(task), limiter.run(task), limiter.run(task)]);
  assert.equal(peak, 1);
});

test('parses Retry-After seconds and dates', () => {
  assert.equal(parseRetryAfterMs('12'), 12_000);
  assert.equal(parseRetryAfterMs(null), null);
  assert.equal(parseRetryAfterMs(new Date(5000).toUTCString(), 1000), 4000);
});

test('opens a circuit after repeated exhausted retries and fails fast until it closes', async () => {
  const clock = fakeClock();
  const limiter = new LlmRateLimiter(
    { minIntervalMs: 0, maxRetries: 0, circuitThreshold: 2, circuitBaseMs: 60_000 },
    { sleep: clock.sleep, now: clock.now, logger: {} }
  );
  const down = async () => ({ status: 502, headers: new Headers() });
  await limiter.run(down);
  assert.equal(limiter.isCircuitOpen(), false);
  await limiter.run(down);
  assert.equal(limiter.isCircuitOpen(), true);

  let sent = 0;
  await assert.rejects(
    limiter.run(async () => {
      sent += 1;
      return ok();
    }),
    { name: 'LlmUnavailableError' }
  );
  assert.equal(sent, 0);

  clock.time += 61_000;
  assert.equal(limiter.isCircuitOpen(), false);
  const response = await limiter.run(async () => ok());
  assert.equal(response.status, 200);
  assert.equal(limiter.consecutiveFailures, 0);
});

test('a probe that fails after the circuit closes reopens it for longer', async () => {
  const clock = fakeClock();
  const limiter = new LlmRateLimiter(
    { minIntervalMs: 0, maxRetries: 0, circuitThreshold: 1, circuitBaseMs: 60_000 },
    { sleep: clock.sleep, now: clock.now, logger: {} }
  );
  const down = async () => ({ status: 503, headers: new Headers() });
  await limiter.run(down);
  const firstOpenUntil = limiter.circuitOpenUntil - clock.time;
  clock.time += 61_000;
  await limiter.run(down);
  assert.ok(limiter.circuitOpenUntil - clock.time > firstOpenUntil);
});
