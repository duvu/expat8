## Why

The `POST /v1/learning/cards` endpoint currently does not consistently return words, leaving the mobile app with an empty card feed. Additionally, the mobile app has no proactive prefetch strategy — it does not batch-load words in advance or enforce the 1000-word local cap per-load-cycle. Users see empty sessions or stale content because the feed pipeline and the local cache management are both broken or incomplete.

## What Changes

- **Backend**: Fix `POST /v1/learning/cards` to always return exactly `limit` words (default 10) per request, generating AI vocabulary if the stored pool is insufficient.
- **Mobile**: On first launch, prefetch an initial batch of 10 words from the backend into local storage before showing the learning screen.
- **Mobile**: As the local word queue drains (≤ 3 unlearned words remaining), proactively fetch the next batch of 10 words in the background.
- **Mobile**: Enforce a hard cap of 1000 words in local storage. When a new batch of 10 would exceed the cap, the 10 oldest words are pruned before the new 10 are inserted.
- **Mobile**: Local word count never exceeds 1000 at any point during normal operation.

## Capabilities

### New Capabilities
- `mobile-word-prefetch`: Mobile prefetch strategy — initial 10-word batch load, low-watermark background refill, and 1000-word local cap enforcement per-batch.

### Modified Capabilities
- `backend-word-feed-sync`: Backend `POST /v1/learning/cards` must reliably return exactly `limit` (default 10) words, triggering AI generation when stored words are exhausted.
- `mobile-local-cache-sync`: Local word retention cap enforcement is now triggered at each batch insertion, not only on demand.

## Impact

- **Backend**: `src/server.js` or route handler for `POST /v1/learning/cards`; word generation pipeline (`generation_service.js`).
- **Mobile**: `word_repository.dart` (prefetch trigger logic); `local_database.dart` (pruneToMostRecent called on batch insert); `learning_session_controller.dart` (low-watermark detection); `backend_api_client.dart` (batch fetch call).
- **No breaking API changes** — request/response contract for `POST /v1/learning/cards` is unchanged; only backend behavior is fixed.
