## 1. Baseline and Regression Tests

- [x] 1.1 Add backend regression tests proving `/v1/words/next` does not call AI generation when DB inventory is empty.
- [x] 1.2 Add backend scheduler tests for under-1000 minute fill behavior and over-1000 daily top-up behavior.
- [x] 1.3 Add backend selection tests for 15% new / 85% review batch targeting and shortage fallback.
- [x] 1.4 Add backend persistence tests for append-only repeated study events and latest `user_word_states` projection.
- [x] 1.5 Add backend cache inventory tests for full inventory replacement, unknown word filtering, and 1000-ID cap behavior.
- [x] 1.6 Add mobile tests for easy-rated local deletion while preserving queued study-event payloads.
- [x] 1.7 Add mobile tests for cache inventory sync after startup, refill, prune, and easy deletion.

## 2. Backend Schema and Store Contracts

- [x] 2.1 Add PostgreSQL schema/migration support for generation run metadata.
- [x] 2.2 Add PostgreSQL scheduler lock support using either advisory locks or a lock table with expiration.
- [x] 2.3 Add PostgreSQL schema/migration support for `user_cached_words`.
- [x] 2.4 Clarify and enforce uniqueness/indexes for latest learner word state in `user_word_states`.
- [x] 2.5 Extend the store interface with word pool counting and generation run recording.
- [x] 2.6 Extend the store interface with cache inventory replacement and lookup.
- [x] 2.7 Extend the store interface with latest word-state upsert and selection queries.
- [x] 2.8 Keep in-memory store behavior aligned for unit tests and local development.

## 3. Backend Vocabulary Pool Scheduler

- [x] 3.1 Add runtime config for `VOCAB_POOL_MIN_SIZE`, `VOCAB_FILL_INTERVAL_SECONDS`, `VOCAB_DAILY_GENERATION_COUNT`, `VOCAB_DAILY_GENERATION_HOUR_UTC`, and `VOCAB_GENERATION_BATCH_SIZE`.
- [x] 3.2 Implement vocabulary pool inspection per target language.
- [x] 3.3 Implement minute-cadence fill generation while a language pool is below 1000 usable words.
- [x] 3.4 Implement daily +10 top-up generation after a language pool reaches the configured minimum.
- [x] 3.5 Add scheduler ownership locking so multiple backend instances do not generate the same language concurrently.
- [x] 3.6 Record generation run success/failure metadata without exposing secrets.
- [x] 3.7 Wire scheduler startup/shutdown into backend runtime without blocking HTTP server startup.
- [x] 3.8 Ensure generation failures are logged and retried later without affecting mobile card responses.

## 4. Backend Card Selection and API

- [x] 4.1 Remove AI generation fallback from `/v1/words/next` request handling.
- [x] 4.2 Preserve `/v1/words/next` compatibility as a database-only endpoint.
- [x] 4.3 Implement a backend card selection service that resolves anonymous `device_id` and signed-in `user_id`.
- [x] 4.4 Implement review-card selection from latest learner word state and due review time.
- [x] 4.5 Implement new-card selection excluding completed/mastered words and active cached words.
- [x] 4.6 Implement 15% new / 85% review batch targeting with actual mix metadata.
- [x] 4.7 Implement shortage fallback when either new or review pool is unavailable.
- [x] 4.8 Add a batch learning-card API endpoint for backend-selected cards.
- [x] 4.9 Add response metadata for target mix, actual mix, card type, and selection reason.

## 5. Study Events and Easy Completion Semantics

- [x] 5.1 Update single study-event ingestion to upsert latest `user_word_states` after storing accepted events.
- [x] 5.2 Update batch sync ingestion to upsert latest `user_word_states` for each accepted event.
- [x] 5.3 Preserve idempotent handling of repeated `client_event_id` values.
- [x] 5.4 Ensure repeated study attempts for the same word create distinct events when `client_event_id` differs.
- [x] 5.5 Map `easy` events to completed/excluded state for future new-card selection.
- [x] 5.6 Keep non-easy ratings eligible for review according to simple near-term review state.
- [x] 5.7 Add signed-in user handling that prefers `user_id` state while retaining `device_id` context.

## 6. Backend Cache Inventory API

- [x] 6.1 Add signed `/v1/user-word-cache` inventory replacement endpoint.
- [x] 6.2 Validate `device_id`, `server_word_ids`, inventory size, and timestamp fields.
- [x] 6.3 Filter or reject unknown word IDs according to the documented contract.
- [x] 6.4 Replace stale inventory rows for a device with the latest submitted list.
- [x] 6.5 Ensure cache inventory is used only for duplicate avoidance, not authorization or study proof.
- [x] 6.6 Add API tests for anonymous and signed-in cache inventory submissions.

## 7. Mobile Cache Inventory and Refill Flow

- [x] 7.1 Add mobile API client support for cache inventory sync.
- [x] 7.2 Add mobile API client support for backend-selected learning-card batches.
- [x] 7.3 Add local database helpers to list active cached `server_word_id` values for inventory sync.
- [x] 7.4 Trigger inventory sync at app startup after `device_id` and optional session are loaded.
- [x] 7.5 Trigger inventory sync after local refill, prune, and easy-rated deletion.
- [x] 7.6 Replace mobile-owned daily vocabulary refresh assumptions with backend batch refill below threshold.
- [x] 7.7 Keep local fallback/offline behavior when backend refill fails.
- [x] 7.8 Ensure local cache remains capped at 1000 words.

## 8. Mobile Easy Rating and Session Behavior

- [x] 8.1 Update local rating flow so `easy` writes the study event before deleting the local word.
- [x] 8.2 Delete easy-rated words from `local_words` while preserving pending sync queue payloads.
- [x] 8.3 Request or display a replacement card after easy-rated deletion.
- [x] 8.4 Keep hard/too-hard ratings in local review flow according to existing review behavior.
- [x] 8.5 Consume backend card type metadata when storing refill batches.
- [x] 8.6 Update session logs for backend batch refill, easy deletion, and inventory sync.

## 9. Documentation and Contracts

- [x] 9.1 Update `contracts/api.md` with learning-card batch and cache inventory endpoints.
- [x] 9.2 Update backend setup docs with vocabulary scheduler config and operational behavior.
- [x] 9.3 Update mobile setup/docs to describe backend-managed refill and easy deletion semantics.
- [x] 9.4 Update or supersede `docs/backend-vocabulary-generation-and-selection.md` if implementation decisions diverge.
- [x] 9.5 Document relationship to `mobile-vocabulary-prefetch-refresh` and remove conflicting mobile-owned refresh assumptions.

## 10. Verification

- [x] 10.1 Run backend tests covering scheduler, word feed, selection, cache inventory, study events, and persistence.
- [x] 10.2 Run Flutter analyzer.
- [x] 10.3 Run mobile tests covering cache inventory, easy deletion, refill, local fallback, and sync preservation.
- [x] 10.4 Run an end-to-end smoke flow: scheduler fills words, mobile requests batch, user rates easy, backend excludes word from future selection.
- [x] 10.5 Run `openspec validate backend-managed-vocabulary-pool-selection`.
- [x] 10.6 Run `openspec status --change backend-managed-vocabulary-pool-selection` and confirm all artifacts remain complete.
