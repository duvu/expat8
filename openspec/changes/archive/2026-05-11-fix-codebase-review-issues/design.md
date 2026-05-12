## Context

A codebase review identified 12 issues across three layers: backend Node.js/Express API, PostgreSQL persistence, and Flutter mobile client. Issues include a silent API parameter mismatch (mobile sends `exclude_ids`, backend reads nothing), a timing-safe comparison leak, missing auth rate limiting, unvalidated user input, an unindexed foreign key, in-memory full scans, and test gaps.

Current tech stack: Node.js ESM + Express backend, `pg` pool for PostgreSQL, Flutter mobile app with `http` package for API calls.

## Goals / Non-Goals

**Goals:**
- Fix all 12 issues identified in the review
- No breaking API changes — all fixes are either additive or internal
- Each fix is independently testable
- Keep the fix set cohesive: deliver as a single change to avoid partial-state across multiple branches

**Non-Goals:**
- Architectural refactor of word store abstraction layer (WordStore vs PostgresWordStore duplication is noted but not addressed here — too broad)
- Distributed rate limiting (Redis-backed) — in-process is sufficient for single-instance deployment
- Adding new product features or changing existing API schemas beyond the `exclude_server_word_id` parameter addition

## Decisions

### 1. `/v1/words/recent` — Add `exclude_server_word_id` support

**Decision**: Read `request.query.exclude_server_word_id` in the `/v1/words/recent` handler using the same `normalizeExcludedWordIds` helper already used by `/v1/words/next`. Pass the exclude list into `store.recentWords()`.

**Rationale**: The parameter name `exclude_server_word_id` is already established in the API contract and used by `/v1/words/next`. Reusing the same name and helper maintains consistency. Mobile client simply renames `exclude_ids` → `exclude_server_word_id`.

**Alternative considered**: Add a new `exclude_ids` parameter name to the backend. Rejected — introduces a second synonym with no benefit.

### 2. Timing-safe comparison — length normalization

**Decision**: Before calling `crypto.timingSafeEqual`, hash both sides with SHA-256 (fixed 32-byte output). This eliminates the length branch entirely.

```javascript
function timingSafeEqual(left, right) {
  const h = (v) => crypto.createHash('sha256').update(v).digest();
  return crypto.timingSafeEqual(h(left), h(right));
}
```

**Rationale**: The current code returns early if `leftBuffer.length !== rightBuffer.length`, leaking whether the lengths matched. Hashing both sides first guarantees equal-length buffers and preserves constant-time comparison. Overhead is negligible (single SHA-256 per auth request).

**Alternative considered**: Pad shorter buffer with zeros. Rejected — introduces subtle bugs if padding character appears in valid inputs.

### 3. Rate limiting — `express-rate-limit`

**Decision**: Use `express-rate-limit` (already used widely in Express ecosystems, no transitive deps). Apply separate limiters to `/v1/users/register` (10 requests / 15 min per IP) and `/v1/users/sign-in` (20 requests / 15 min per IP).

**Rationale**: In-process limiting is sufficient for single-instance deployment. Limits are generous enough to not block legitimate users (e.g. flaky network retries) but block automated brute force. Window is reset per IP not per user to avoid user enumeration.

**Alternative considered**: nginx-level rate limiting. Rejected — requires infrastructure config outside the codebase; in-process is simpler to test.

### 4. Invalid bearer token — explicit 401

**Decision**: In `resolveOptionalUserSession`, if an `Authorization` header is present but the token lookup returns no session, return `401` immediately instead of silently treating as anonymous.

**Rationale**: Silently downgrading a request with a bearer token to anonymous is a security smell. If the client sent a token and it's invalid (expired, tampered), the server should say so explicitly.

**Scope**: Only on endpoints that call `resolveOptionalUserSession`. Endpoints using `requireUserSession` already return 401 correctly.

### 5. `occurred_at` validation

**Decision**: Before `new Date(event.occurred_at)`, check `Number.isNaN(Date.parse(event.occurred_at))`. If invalid, the handler returns `400 bad_request`. Validation happens in `app.js` before passing to the store.

**Rationale**: Keeps validation at the API boundary (app.js), not deep in the store. Consistent with where other input validation lives.

### 6. SQL optimisation for `learningCards()`

**Decision**: Replace the load-all + filter-in-memory pattern with a SQL query using `LEFT JOIN user_word_states` and filtering/limiting in the database. Also add a migration to create `idx_user_word_states_word_id`.

**Rationale**: Full table scans are acceptable at development scale but will fail under production load. The JOIN approach is correct and performant.

### 7. Postgres pool config

**Decision**: Add explicit pool options in `createStore`: `max: 20`, `idleTimeoutMillis: 30000`, `connectionTimeoutMillis: 5000`. These become part of `config.js` as optional overrides.

**Rationale**: Express default pool of 10 is fine for low traffic but explicit config makes behavior predictable and observable.

### 8. Language code validation

**Decision**: Maintain a `VALID_LANGUAGES` Set in `config.js` (initially `['en', 'zh', 'vi']`, configurable). Validate `target_language` in `app.js` at the endpoint level; return `400` for unknown values.

**Alternative considered**: Validate in the store layer. Rejected — API boundary validation gives earlier, cleaner error messages.

### 9. Named constants

**Decision**: Extract magic numbers in `word_store.js` and `proficiency.js` to top-level named constants:
- `PROFICIENCY_LEVEL_UP_THRESHOLD = 5`
- `NEW_CARD_RATIO = 0.15`
- `WORD_CACHE_LIMIT = 1000`

### 10. Sign-out test

**Decision**: Add a test to `api.test.js` that calls sign-out with a valid token then verifies subsequent authenticated requests return 401.

## Risks / Trade-offs

- **Rate limiter in-process state**: If the server restarts, rate limit counters reset. Acceptable for MVP; upgrade to Redis-backed if needed.
- **SHA-256 overhead on auth**: Sub-microsecond cost, effectively zero in context.
- **`learningCards` SQL rewrite**: Risk of regression in query behavior; mitigated by existing test suite + new tests added in tasks.
- **`exclude_server_word_id` on `/v1/words/recent`**: Backend endpoint was previously unauthenticated and stateless; adding the filter makes the response vary by input but the endpoint remains unauthenticated (device-scoped vocabulary, not user-scoped).

## Migration Plan

1. Deploy backend with all fixes in a single release
2. Mobile app update ships new parameter name `exclude_server_word_id` — old mobile clients using `exclude_ids` on `/recent` will continue to work (they just won't get deduplication, same as today — no regression)
3. DB migration adds index on `user_word_states(word_id)` — safe online migration, no table lock

## Open Questions

- Should `VALID_LANGUAGES` be stored in the database (to support dynamic language expansion)? For now, a config-driven Set is sufficient. Revisit when the language registry feature ships.
