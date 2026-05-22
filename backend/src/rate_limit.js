/**
 * Simple in-process sliding-window rate limiter.
 *
 * Each bucket is identified by a string key (e.g. IP + endpoint).  The limiter
 * counts requests in a rolling window and rejects once the cap is reached.
 *
 * This is intentionally in-process (no Redis / Postgres dependency) so that
 * the dev/test path works without external services.  For multi-instance
 * deployments the window is slightly wider than the true sliding window but
 * still provides a meaningful first-line defence.
 */
export class InMemoryRateLimiter {
  /**
   * @param {object} options
   * @param {number} options.windowMs   - Rolling window duration in ms (default 60 000)
   * @param {number} options.maxRequests - Max requests per key per window (default 60)
   */
  constructor({ windowMs = 60_000, maxRequests = 60 } = {}) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
    /** @type {Map<string, number[]>} key → sorted array of request timestamps */
    this._buckets = new Map();
  }

  /**
   * Check whether a request should be allowed.
   *
   * @param {string} key
   * @param {number} [nowMs]
   * @returns {{ allowed: boolean, remaining: number, resetMs: number }}
   */
  check(key, nowMs = Date.now()) {
    const cutoff = nowMs - this.windowMs;
    let timestamps = this._buckets.get(key) ?? [];

    // Evict expired entries
    timestamps = timestamps.filter((t) => t > cutoff);

    const allowed = timestamps.length < this.maxRequests;
    if (allowed) {
      timestamps.push(nowMs);
    }

    this._buckets.set(key, timestamps);

    const oldest = timestamps[0] ?? nowMs;
    return {
      allowed,
      remaining: Math.max(0, this.maxRequests - timestamps.length),
      resetMs: oldest + this.windowMs
    };
  }

  /** Prune all expired buckets — call periodically to reclaim memory. */
  prune(nowMs = Date.now()) {
    const cutoff = nowMs - this.windowMs;
    for (const [key, timestamps] of this._buckets) {
      const fresh = timestamps.filter((t) => t > cutoff);
      if (fresh.length === 0) {
        this._buckets.delete(key);
      } else {
        this._buckets.set(key, fresh);
      }
    }
  }
}

/**
 * Build an Express middleware that enforces a rate limit per remote IP (or
 * device_id when present in the request body).
 *
 * @param {InMemoryRateLimiter} limiter
 * @param {object} [options]
 * @param {string} [options.keyPrefix]  - Prefix for the bucket key, e.g. "auth"
 * @param {Function} [options.keyFn]    - Custom function (req) → string key
 * @returns {Function} Express middleware
 */
export function rateLimitMiddleware(limiter, { keyPrefix = '', keyFn } = {}) {
  return (request, response, next) => {
    const baseKey = keyFn ? keyFn(request) : (request.body?.device_id ?? request.ip ?? 'unknown');
    const key = keyPrefix ? `${keyPrefix}:${baseKey}` : baseKey;
    const { allowed, remaining, resetMs } = limiter.check(key);

    response.setHeader('X-RateLimit-Remaining', remaining);
    response.setHeader('X-RateLimit-Reset', Math.ceil(resetMs / 1000));

    if (!allowed) {
      return response.status(429).json({ error: 'rate_limit_exceeded' });
    }
    return next();
  };
}
