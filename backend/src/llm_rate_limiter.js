const DEFAULTS = {
  minIntervalMs: 3000,
  maxConcurrent: 1,
  maxRetries: 4,
  backoffBaseMs: 15_000,
  backoffMaxMs: 10 * 60_000,
  maxRequestsPerHour: 120,
  circuitThreshold: 2,
  circuitBaseMs: 5 * 60_000,
  circuitMaxMs: 60 * 60_000
};
const RETRYABLE_STATUSES = new Set([429, 502, 503, 504]);

export class LlmUnavailableError extends Error {
  constructor(retryInMs) {
    super(`LLM gateway unavailable (circuit open, retry in ${Math.ceil(retryInMs / 1000)}s)`);
    this.name = 'LlmUnavailableError';
  }
}

/**
 * Process-wide throttle for the LLM gateway (OmniRoute). Every request is queued, started at least
 * `minIntervalMs` after the previous one, and capped at `maxConcurrent` in flight and
 * `maxRequestsPerHour` per rolling hour. A 429/5xx response puts the whole limiter into cooldown
 * (honouring `Retry-After`) and the request is retried with exponential backoff, so background
 * generation can never stampede the gateway or starve user-submitted words.
 */
export class LlmRateLimiter {
  constructor(options = {}, { sleep = defaultSleep, now = Date.now, logger = console } = {}) {
    Object.assign(this, DEFAULTS, stripUndefined(options));
    this.sleep = sleep;
    this.now = now;
    this.logger = logger;
    this.inFlight = 0;
    this.lastStartAt = 0;
    this.cooldownUntil = 0;
    this.startTimes = [];
    this.waiters = [];
    // Consecutive requests that exhausted every retry; after `circuitThreshold` the circuit opens and
    // callers fail fast instead of piling retries onto a gateway that has no working provider.
    this.consecutiveFailures = 0;
    this.circuitOpenUntil = 0;
  }

  /** Runs `request` (returns a fetch Response) under the throttle, retrying throttled responses. */
  async run(request) {
    if (this.isCircuitOpen()) {
      throw new LlmUnavailableError(this.circuitOpenUntil - this.now());
    }
    for (let attempt = 0; ; attempt += 1) {
      await this.#acquire();
      let response;
      try {
        response = await request();
      } finally {
        this.#release();
      }
      if (!RETRYABLE_STATUSES.has(response.status)) {
        this.consecutiveFailures = 0;
        return response;
      }
      if (attempt >= this.maxRetries) {
        this.#recordExhausted();
        return response;
      }
      const delayMs = this.#cooldownFor(response, attempt);
      this.cooldownUntil = Math.max(this.cooldownUntil, this.now() + delayMs);
      this.logger.warn?.('llm_rate_limited', { status: response.status, attempt: attempt + 1, delay_ms: delayMs });
    }
  }

  /** True while the gateway is considered down; background jobs should not start LLM work. */
  isCircuitOpen() {
    return this.circuitOpenUntil > this.now();
  }

  #recordExhausted() {
    this.consecutiveFailures += 1;
    if (this.consecutiveFailures < this.circuitThreshold) {
      return;
    }
    const openMs = Math.min(
      this.circuitMaxMs,
      this.circuitBaseMs * 2 ** (this.consecutiveFailures - this.circuitThreshold)
    );
    this.circuitOpenUntil = this.now() + openMs;
    this.logger.warn?.('llm_circuit_opened', { consecutive_failures: this.consecutiveFailures, open_ms: openMs });
  }

  /** Requests started in the last hour; lets schedulers skip optional work when nearly out of budget. */
  requestsInLastHour() {
    this.#pruneWindow();
    return this.startTimes.length;
  }

  remainingHourlyBudget() {
    return Math.max(0, this.maxRequestsPerHour - this.requestsInLastHour());
  }

  inCooldown() {
    return this.cooldownUntil > this.now();
  }

  #cooldownFor(response, attempt) {
    const retryAfter = parseRetryAfterMs(response.headers?.get?.('retry-after'), this.now());
    const backoff = Math.min(this.backoffMaxMs, this.backoffBaseMs * 2 ** attempt);
    return Math.min(this.backoffMaxMs, Math.max(retryAfter ?? 0, backoff));
  }

  async #acquire() {
    if (this.inFlight >= this.maxConcurrent) {
      await new Promise((resolve) => this.waiters.push(resolve));
    }
    this.inFlight += 1;
    try {
      // Re-check after every sleep: another caller may have extended the cooldown meanwhile.
      for (;;) {
        this.#pruneWindow();
        const now = this.now();
        const budgetWait =
          this.startTimes.length >= this.maxRequestsPerHour ? this.startTimes[0] + 3_600_000 - now : 0;
        const waitMs = Math.max(this.lastStartAt + this.minIntervalMs - now, this.cooldownUntil - now, budgetWait);
        if (waitMs <= 0) {
          break;
        }
        await this.sleep(waitMs);
      }
    } catch (error) {
      this.#release();
      throw error;
    }
    this.lastStartAt = this.now();
    this.startTimes.push(this.lastStartAt);
  }

  #release() {
    this.inFlight -= 1;
    this.waiters.shift()?.();
  }

  #pruneWindow() {
    const cutoff = this.now() - 3_600_000;
    while (this.startTimes.length > 0 && this.startTimes[0] <= cutoff) {
      this.startTimes.shift();
    }
  }
}

export function parseRetryAfterMs(value, now = Date.now()) {
  if (!value) {
    return null;
  }
  const seconds = Number(value);
  if (Number.isFinite(seconds)) {
    return Math.max(0, seconds * 1000);
  }
  const date = Date.parse(value);
  return Number.isNaN(date) ? null : Math.max(0, date - now);
}

let sharedLimiter = null;

/** One limiter per process so the API scheduler, article worker and crawler share the same budget. */
export function getSharedLlmRateLimiter(config = {}, logger = console) {
  sharedLimiter ??= new LlmRateLimiter(
    {
      minIntervalMs: config.llmMinIntervalMs,
      maxConcurrent: config.llmMaxConcurrent,
      maxRetries: config.llmMaxRetries,
      backoffBaseMs: config.llmBackoffBaseMs,
      maxRequestsPerHour: config.llmMaxRequestsPerHour
    },
    { logger }
  );
  return sharedLimiter;
}

function stripUndefined(object) {
  return Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined && !Number.isNaN(value)));
}

function defaultSleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
