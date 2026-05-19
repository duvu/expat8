import crypto from 'node:crypto';

const SIGNATURE_VERSION = 'v1';

export class InMemoryNonceCache {
  constructor() {
    this.entries = new Map();
  }

  use(appId, nonce, nowMs, ttlSeconds) {
    // Node.js runs on a single thread, so the check-then-set below is atomic —
    // no concurrent request can interleave between `has` and `set`.
    this.prune(nowMs);
    const key = `${appId}:${nonce}`;
    if (this.entries.has(key)) {
      return false;
    }
    this.entries.set(key, nowMs + ttlSeconds * 1000);
    return true;
  }

  prune(nowMs) {
    for (const [key, expiresAt] of this.entries.entries()) {
      if (expiresAt <= nowMs) {
        this.entries.delete(key);
      }
    }
  }
}

/**
 * PostgreSQL-backed nonce cache for multi-instance replay protection.
 *
 * Uses an `INSERT … ON CONFLICT DO NOTHING` to atomically claim a nonce.
 * A non-zero row count means the nonce is fresh; zero means it was already used.
 * Expired rows are pruned lazily (at most once per minute) via a fire-and-forget
 * DELETE, so the table stays small without a separate cron job.
 *
 * Falls back to accepting the request on any database error so a transient
 * Postgres hiccup does not lock out legitimate clients — an acceptable tradeoff
 * given that timestamp-based skew checks bound the replay window.
 */
export class PostgresNonceCache {
  #pool;
  #lastPruneMs;
  #pruneIntervalMs;

  constructor(pool, { pruneIntervalMs = 60_000 } = {}) {
    this.#pool = pool;
    this.#lastPruneMs = 0;
    this.#pruneIntervalMs = pruneIntervalMs;
  }

  async use(appId, nonce, nowMs, ttlSeconds) {
    const expiresAt = new Date(nowMs + ttlSeconds * 1000);
    try {
      const result = await this.#pool.query(
        `INSERT INTO nonces (app_id, nonce, expires_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (app_id, nonce) DO NOTHING`,
        [appId, nonce, expiresAt]
      );
      const claimed = result.rowCount > 0;
      if (claimed) {
        this.#maybePrune(nowMs);
      }
      return claimed;
    } catch {
      // Fail-open: a DB error should not block authenticated clients.
      return true;
    }
  }

  #maybePrune(nowMs) {
    if (nowMs - this.#lastPruneMs < this.#pruneIntervalMs) {
      return;
    }
    this.#lastPruneMs = nowMs;
    // Fire-and-forget — errors are intentionally swallowed.
    this.#pool.query('DELETE FROM nonces WHERE expires_at <= NOW()').catch(() => {});
  }
}

export function canonicalPathWithSortedQuery(url) {
  const sortedParams = [...url.searchParams.entries()].sort(([leftKey, leftValue], [rightKey, rightValue]) => {
    if (leftKey === rightKey) {
      return leftValue.localeCompare(rightValue);
    }
    return leftKey.localeCompare(rightKey);
  });

  const query = new URLSearchParams();
  for (const [key, value] of sortedParams) {
    query.append(key, value);
  }

  const queryString = query.toString();
  return queryString ? `${url.pathname}?${queryString}` : url.pathname;
}

export function hashBody(rawBody) {
  return crypto.createHash('sha256').update(rawBody).digest('base64url');
}

export function buildCanonicalRequest({ method, url, timestamp, nonce, contentSha256 }) {
  return [
    SIGNATURE_VERSION,
    method.toUpperCase(),
    canonicalPathWithSortedQuery(url),
    timestamp,
    nonce,
    contentSha256
  ].join('\n');
}

export function signCanonicalRequest({ secret, canonicalRequest }) {
  const signature = crypto.createHmac('sha256', secret).update(canonicalRequest).digest('base64url');
  return `${SIGNATURE_VERSION}=${signature}`;
}

export async function verifyAppCredentialRequest({ method, url, headers, rawBody, config, nonceCache, now }) {
  const appId = headerValue(headers, 'x-expat8-app-id');
  const timestamp = headerValue(headers, 'x-expat8-timestamp');
  const nonce = headerValue(headers, 'x-expat8-nonce');
  const contentSha256 = headerValue(headers, 'x-expat8-content-sha256');
  const signature = headerValue(headers, 'x-expat8-signature');

  if (!appId || !timestamp || !nonce || !contentSha256 || !signature) {
    return { ok: false };
  }

  if (contentSha256 !== hashBody(rawBody)) {
    return { ok: false };
  }

  const requestTime = Date.parse(timestamp);
  if (Number.isNaN(requestTime)) {
    return { ok: false };
  }
  const nowMs = now.getTime();
  if (Math.abs(nowMs - requestTime) > config.appCredentialTimestampSkewSeconds * 1000) {
    return { ok: false };
  }

  const credential = config.appCredentials.find(
    (candidate) => candidate.appId === appId && candidate.status === 'active'
  );
  if (!credential) {
    return { ok: false };
  }

  const canonicalRequest = buildCanonicalRequest({
    method,
    url,
    timestamp,
    nonce,
    contentSha256
  });
  const expectedSignature = signCanonicalRequest({
    secret: credential.secret,
    canonicalRequest
  });
  if (!timingSafeEqual(signature, expectedSignature)) {
    return { ok: false };
  }

  if (!(await nonceCache.use(appId, nonce, nowMs, config.appCredentialNonceTtlSeconds))) {
    return { ok: false };
  }

  return { ok: true, appId };
}

function headerValue(headers, name) {
  const value = headers[name] ?? headers[name.toLowerCase()];
  if (Array.isArray(value)) {
    return value[0];
  }
  return typeof value === 'string' ? value : '';
}

function timingSafeEqual(left, right) {
  // Hash both operands to a fixed-length digest before comparing.
  // This removes the length-check branch that would leak whether the
  // operand lengths matched, preserving constant-time semantics.
  const hash = (v) => crypto.createHash('sha256').update(v).digest();
  return crypto.timingSafeEqual(hash(left), hash(right));
}
