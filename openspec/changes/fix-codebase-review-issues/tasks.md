## 1. Fix API Parameter Mismatch — `exclude_server_word_id` on `/v1/words/recent`

- [x] 1.1 In `backend/src/app.js`, update the `/words/recent` handler to read `request.query.exclude_server_word_id` using the existing `normalizeExcludedWordIds` helper
- [x] 1.2 Update `store.recentWords()` call in the handler to pass the `excludeServerWordIds` list
- [x] 1.3 In `backend/src/word_store.js`, update `WordStore.recentWords()` signature to accept and apply `excludeServerWordIds` filter
- [x] 1.4 In `backend/src/postgres_word_store.js`, update `PostgresWordStore.recentWords()` to apply `WHERE id NOT IN (...)` when exclude list is non-empty
- [x] 1.5 In `mobile/lib/src/api/backend_api_client.dart`, rename `exclude_ids` → `exclude_server_word_id` in `fetchRecentWords()`
- [x] 1.6 Update `mobile/test/backend_api_client_test.dart` to assert `exclude_server_word_id` instead of `exclude_ids`
- [x] 1.7 Add a backend API test in `backend/test/api.test.js` verifying that `exclude_server_word_id` on `/v1/words/recent` filters out specified word IDs

## 2. Fix Timing-Safe Comparison Leak

- [x] 2.1 In `backend/src/app_credentials.js`, rewrite `timingSafeEqual` to hash both operands with SHA-256 before calling `crypto.timingSafeEqual` (removes length-check branch)
- [x] 2.2 In `backend/src/user_identity.js`, apply the same fix to its local `timingSafeEqual` function
- [x] 2.3 Add a test in `backend/test/app_credentials.test.js` asserting that comparing strings of different lengths returns `false` without throwing

## 3. Add Rate Limiting on Auth Endpoints

- [x] 3.1 Add `express-rate-limit` to `backend/package.json` dependencies
- [x] 3.2 In `backend/src/app.js`, create a `registrationLimiter` (10 req / 15 min per IP) and a `signInLimiter` (20 req / 15 min per IP) using `express-rate-limit`
- [x] 3.3 Apply `registrationLimiter` to the `/users/register` route and `signInLimiter` to the `/users/sign-in` route
- [x] 3.4 Add tests in `backend/test/api.test.js` verifying the 429 response when the limit is exceeded (use a low-limit test fixture)

## 4. Reject Invalid Bearer Tokens Explicitly

- [x] 4.1 In `backend/src/app.js`, update `resolveOptionalUserSession` so that if an `Authorization: Bearer` header is present but the token resolves to no session, the function writes a `401` response and returns `false`
- [x] 4.2 Add a test in `backend/test/api.test.js` verifying that a request with a made-up bearer token on an optional-auth endpoint returns `401`

## 5. Validate `occurred_at` Timestamp

- [x] 5.1 In `backend/src/app.js`, in the `/study-events` POST handler, validate `body.occurred_at` with `Number.isNaN(Date.parse(body.occurred_at))` and return `400` if invalid
- [x] 5.2 Add a test in `backend/test/api.test.js` verifying that a study event with `occurred_at: "not-a-date"` returns `400 bad_request`

## 6. SQL Optimisation — `learningCards()` and Missing Index

- [x] 6.1 Create a new migration file `backend/db/migrations/<next>-add-user-word-states-word-id-index.sql` with `CREATE INDEX IF NOT EXISTS idx_user_word_states_word_id ON user_word_states(word_id);`
- [x] 6.2 Apply the migration in `backend/db/schema.sql` so fresh installs include the index
- [x] 6.3 Rewrite the `learningCards()` query in `backend/src/postgres_word_store.js` to use a SQL `LEFT JOIN user_word_states` + `WHERE` + `LIMIT` instead of loading all words and filtering in memory
- [x] 6.4 Verify the rewritten query produces the same results by running existing learning-card tests

## 7. Explicit Postgres Connection Pool Configuration

- [x] 7.1 Add optional config fields to `backend/src/config.js`: `dbPoolMax` (default 20), `dbIdleTimeoutMs` (default 30000), `dbConnectionTimeoutMs` (default 5000)
- [x] 7.2 Update `backend/src/runtime.js` `createStore()` to pass these values when creating the pool: `{ connectionString, max, idleTimeoutMillis, connectionTimeoutMillis }`

## 8. Validate Language Codes

- [x] 8.1 Add `validLanguages` set to `backend/src/config.js` (default: `['en', 'zh', 'vi']`)
- [x] 8.2 In `backend/src/app.js`, add a `validateLanguage(lang)` helper that checks against the set and returns a boolean
- [x] 8.3 Apply the validator to `target_language` in the `/words/next`, `/words/recent`, `/study-events`, and `/proficiency` handlers; return `400 bad_request` on failure
- [x] 8.4 Add tests in `backend/test/api.test.js` verifying that unknown language codes return `400`

## 9. Replace Magic Numbers with Named Constants

- [x] 9.1 In `backend/src/word_store.js`, define `PROFICIENCY_LEVEL_UP_THRESHOLD = 5`, `NEW_CARD_RATIO = 0.15`, `WORD_CACHE_LIMIT = 1000` as top-level named constants and replace all usages
- [x] 9.2 In `backend/src/proficiency.js`, replace any hardcoded threshold values with the same or equivalent named constants

## 10. Add Sign-Out Test Coverage

- [x] 10.1 In `backend/test/api.test.js`, add a test that: signs in, calls sign-out with the token, then calls an authenticated endpoint — verifies the response is `401`

## 11. Document Nonce Cache Concurrency Safety

- [x] 11.1 In `backend/src/app_credentials.js`, add a JSDoc or inline comment on `InMemoryNonceCache.use()` explaining that check-then-set is safe in Node.js single-threaded event loop and that each call completes synchronously without yielding
