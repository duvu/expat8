## Why

The codebase now has several overlapping changes that moved the product toward ObjectBox-only mobile storage and `POST /v1/learning/cards`, but older OpenSpec artifacts, docs, API params, and store implementations still describe or implement parts of the previous design. This change resolves the highest-risk drift so backend, mobile, contracts, tests, OpenSpec, and docs describe one coherent system.

## What Changes

- Fix backend study-event sync response consistency so empty or fully rejected sync batches still return the current proficiency state.
- Make `/v1/learning/cards` card-mode behavior explicit: unsupported `card_mode` values are rejected or removed from the public contract.
- Reconcile `/v1/words/recent` query parameters across mobile, backend, and `contracts/api.md`, including `source_language`, `device_id`, and `excludeIds`.
- Replace timestamp-based mobile app-credential nonces with random nonces that satisfy the credential contract.
- Enforce the mobile local 1000-word cap from the local persistence boundary for every batch insert path.
- Normalize PostgreSQL user proficiency persistence so signed-in user records are keyed by `user_id` instead of synthetic `device_id` values.
- Clarify mobile new-word/refill diagnostic log event semantics so local hits, backend refills, empty refills, and fallback misses are distinguishable.
- Reconcile active OpenSpec changes and current developer docs so they no longer present SQLite or `/v1/words/next` as current behavior unless explicitly marked historical.

## Capabilities

### New Capabilities

- `project-consistency-governance`: Defines source-of-truth rules for API contracts, OpenSpec lifecycle hygiene, current-vs-historical docs, and cross-project consistency checks.
- `mobile-app-credential-signing`: Defines how the mobile app signs `/v1/*` requests, including random nonce generation and canonical request parity with the backend.

### Modified Capabilities

- `backend-word-feed-sync`: Require stable sync response shapes, explicit `card_mode` semantics, and intentional `/v1/words/recent` query parameter handling.
- `backend-postgres-persistence`: Require user-scoped proficiency records to use explicit user uniqueness instead of synthetic device identifiers.
- `mobile-local-cache-sync`: Require local word retention to be enforced by the local database boundary for all batch insert and refill paths.
- `mobile-system-logging`: Require diagnostic log names and context fields to distinguish local cache hits, backend refill success, refill empty, and fallback misses.

## Impact

- **Backend**: `src/app.js`, `src/word_store.js`, `src/postgres_word_store.js`, DB schema/migrations, backend API/store tests, `contracts/api.md`.
- **Mobile**: `BackendApiClient`, `LocalDatabase`, `WordRepository`, `LearningSessionController`, ObjectBox-backed local database tests, repository/API/logging tests.
- **OpenSpec**: active changes that still reference SQLite or `/v1/words/next`, plus completed changes that are ready to archive.
- **Docs**: `README.md`, `mobile/README.md`, `docs/mvp-setup.md`, dated investigation docs that need historical labels, and release notes where needed.
- **Compatibility**: No new product endpoint is introduced. The change may reject previously tolerated unsupported `card_mode` values and may remove unused mobile query params from `/v1/words/recent`.
