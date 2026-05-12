## 1. Baseline Regression Tests

- [x] 1.1 Add in-memory store tests proving `syncStudyEvents({ events: [] })` returns current proficiency.
- [x] 1.2 Add in-memory store tests proving all-rejected sync batches still return current proficiency.
- [x] 1.3 Add PostgreSQL store tests for empty and all-rejected sync batch proficiency response shape.
- [x] 1.4 Add backend API tests proving unsupported `card_mode` values on `POST /v1/learning/cards` return `400 { "error": "bad_request" }`.
- [x] 1.5 Add or update backend API tests proving `/v1/words/recent` behavior matches only documented bootstrap parameters.
- [x] 1.6 Add mobile API client tests proving app credential nonces are distinct for concurrent signed requests.
- [x] 1.7 Add mobile local database tests for batch insert cases that would exceed 1000 words, including count 950 + batch 100 and count 990 + batch 100.
- [x] 1.8 Add mobile logging/repository tests covering local hit, backend refill success, empty refill, and backend-error fallback event semantics.

## 2. Backend API And Store Consistency

- [x] 2.1 Refactor `WordStore.syncStudyEvents()` to track latest proficiency separately from study-event result wrappers.
- [x] 2.2 Refactor `PostgresWordStore.syncStudyEvents()` to return the same shape as `WordStore` for accepted, empty, and rejected batches.
- [x] 2.3 Enforce `card_mode` validation in the `/v1/learning/cards` route before store selection.
- [x] 2.4 Remove ignored `cardMode` forwarding from store calls unless the store interface is explicitly extended and tested.
- [x] 2.5 Reconcile `/v1/words/recent` route handling so backend reads only contract-backed bootstrap parameters.
- [x] 2.6 Update backend error responses touched by this change so mobile can always read the `error` field.

## 3. PostgreSQL Proficiency Ownership

- [x] 3.1 Create a PostgreSQL migration that deduplicates existing user proficiency rows by user and language.
- [x] 3.2 Add partial unique indexes for anonymous `(device_id, language)` and signed-in `(user_id, language)` proficiency rows.
- [x] 3.3 Update `backend/db/schema.sql` to include explicit user/device proficiency ownership indexes for fresh databases.
- [x] 3.4 Update `PostgresWordStore.getOrInitializeProficiency()` to insert signed-in rows using real `user_id` ownership instead of synthetic `device_id = "user:<id>"`.
- [x] 3.5 Add PostgreSQL tests for anonymous and signed-in proficiency initialization and idempotent conflict behavior.

## 4. Mobile API, Cache, And Logging Consistency

- [x] 4.1 Replace timestamp-derived app credential nonce generation with high-entropy random nonce generation.
- [x] 4.2 Simplify `BackendApiClient.fetchRecentWords()` so mobile sends only supported bootstrap parameters.
- [x] 4.3 Route learner-specific duplicate avoidance and refill/top-up behavior through `/v1/learning/cards` and cache inventory instead of `/v1/words/recent` exclusions.
- [x] 4.4 Move the 1000-word cap enforcement into `LocalDatabase.addBatch()` so every caller finishes within the cap.
- [x] 4.5 Ensure startup prefetch, backend-managed refill, daily refresh, and proactive refresh all use the same capped local write path.
- [x] 4.6 Rename or split new-word/refill log events so local cache hits are not labeled as backend success.
- [x] 4.7 Remove always-false or misleading log context fields such as `fallback_hit` after `localWord == null`.

## 5. Contracts, OpenSpec, And Docs Reconciliation

- [x] 5.1 Update `contracts/api.md` for stricter `card_mode` semantics and the final `/v1/words/recent` parameter set.
- [x] 5.2 Update root `README.md` and `mobile/README.md` to describe the current ObjectBox, app credential, and `/v1/learning/cards` flow.
- [x] 5.3 Update `docs/mvp-setup.md` to remove SQLite/sqflite setup as current guidance and replace stale `GET /v1/learning/cards` references with `POST /v1/learning/cards`.
- [x] 5.4 Update release notes for user-visible or developer-visible behavior changes from this consistency pass.
- [x] 5.5 Reconcile `mobile-vocabulary-prefetch-refresh` OpenSpec artifacts with ObjectBox and `/v1/learning/cards` as the current architecture.
- [x] 5.6 Reconcile `add-adaptive-proficiency-system` OpenSpec artifacts that still describe `/v1/words/next` as implemented behavior.
- [x] 5.7 Archive completed OpenSpec changes that have no remaining implementation tasks, or document why they remain active.
- [x] 5.8 Add historical-source notices to dated investigation docs that still mention SQLite or `/v1/words/next`.

## 6. Verification

- [x] 6.1 Run `cd backend && npm test`.
- [x] 6.2 Run PostgreSQL integration tests when `TEST_DATABASE_URL` is available.
- [x] 6.3 Run `cd mobile && flutter test`.
- [x] 6.4 Run OpenSpec status/validation for `resolve-codebase-consistency-drift`.
- [x] 6.5 Re-run a repo search for stale current-doc references to SQLite, sqflite, `GET /v1/learning/cards`, and `/v1/words/next`.
- [x] 6.6 Confirm `docs/codebase-review-consistency-guide.md` either matches the resolved state or is marked as the pre-change review note.
