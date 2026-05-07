## Why

A codebase review surfaced 12 issues spanning security vulnerabilities, API contract bugs, missing database optimisations, and test gaps. The most critical — an API parameter mismatch that silently discards the `exclude_ids` filter on the recent-words endpoint — means vocabulary prefetch can return duplicates already cached on device, wasting bandwidth and degrading UX. The remaining issues range from timing-safe comparison leaks and missing rate limiting to full in-memory word scans and an unindexed foreign key. Fixing all 12 now prevents accumulation of technical debt before the app goes to broader testing.

## What Changes

- **Bug fix**: Backend `/v1/words/recent` gains support for `exclude_server_word_id` repeated query parameter, mirroring `/v1/words/next`; mobile `fetchRecentWords` updated to send the correct parameter name
- **Security fix**: `timingSafeEqual` in `app_credentials.js` and `user_identity.js` — normalize buffer lengths before comparing to prevent timing-leak on length mismatch
- **Security fix**: Add in-process rate limiting (e.g. via `express-rate-limit`) on `/v1/users/register` and `/v1/users/sign-in`
- **Security fix**: Invalid `Authorization: Bearer <token>` on GET endpoints returns `401` instead of silently falling through to anonymous
- **Bug fix**: Validate `occurred_at` before calling `new Date()` in study-event processing; return `400` for unparseable timestamps
- **Performance fix**: Replace full in-memory word scan in `learningCards()` with SQL `WHERE` + `JOIN`; add missing index on `user_word_states(word_id)`
- **Config fix**: Explicit Postgres connection pool configuration (`max`, `idleTimeoutMillis`, `connectionTimeoutMillis`)
- **Quality fix**: Validate `target_language` against an allowlist (`en`, `zh`, `vi`, …) at API boundary
- **Quality fix**: Replace magic numbers (5 ratings, 15% ratio, 1000 limit) with named constants
- **Test coverage**: Add sign-out + revocation test in `api.test.js`
- **Docs**: Add comment on `InMemoryNonceCache.use()` explaining why single-threaded Node.js makes the check-then-set safe

## Capabilities

### New Capabilities

- `backend-auth-rate-limiting`: Per-endpoint in-process rate limiting on registration and sign-in routes
- `backend-input-validation`: Centralised validation helpers for language codes, timestamps, and bearer token format at the API boundary

### Modified Capabilities

- `backend-word-feed-sync`: `/v1/words/recent` gains `exclude_server_word_id` filter parity with `/v1/words/next`; mobile client updated to use the correct parameter name
- `backend-postgres-persistence`: SQL query optimisation for `learningCards()`, missing index on `user_word_states(word_id)`, explicit pool config
- `backend-app-credential-security`: Timing-safe comparison normalised; nonce-cache concurrency comment added

## Impact

- **Backend**: `app.js`, `postgres_word_store.js`, `word_store.js`, `runtime.js`, `app_credentials.js`, `user_identity.js`, `db/schema.sql` (new migration)
- **Mobile**: `backend_api_client.dart` (parameter rename), `backend_api_client_test.dart`
- **Tests**: `api.test.js` (sign-out, rate-limit, invalid bearer, invalid timestamp), `app_credentials.test.js` (length-mismatch timing)
- **Dependencies**: `express-rate-limit` added to backend `package.json`
- **No breaking API changes** — `exclude_server_word_id` on `/v1/words/recent` is purely additive; mobile parameter rename is a client-side fix
