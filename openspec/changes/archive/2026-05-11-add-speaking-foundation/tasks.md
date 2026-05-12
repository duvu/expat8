## 1. Contracts And Planning

- [x] 1.1 Update `contracts/api.md` with speaking prompt payload fields, speaking event types, typed metadata, and weekly speaking summary response shape.
- [x] 1.2 Document phase 0-3 privacy constraints in docs: audio local-only by default, no raw audio upload, no local audio file paths in backend payloads.
- [x] 1.3 Add a feature flag or runtime configuration switch for mobile speaking foundation so rollout can be limited to internal/beta users.
- [x] 1.4 Choose the initial English-only prompt scope and create a curated seed set target of 50-200 beginner-friendly prompts.

## 2. Backend Data Model And Migrations

- [x] 2.1 Add an idempotent backend migration for `speaking_prompts` linked to `word_senses` and optionally `article_terms`.
- [x] 2.2 Add fields for prompt target text, Vietnamese hint, target phrase, pronunciation tip, common mistake, difficulty, topic, status, timestamps, and reviewer metadata.
- [x] 2.3 Add an idempotent backend migration for `speaking_events` keyed by client event ID or event ID for idempotent sync.
- [x] 2.4 Add allowed speaking metadata fields for attempt ID, prompt ID, word sense or word ID, duration, retry count, self-rating, occurred-at, device ID, and user ID.
- [x] 2.5 Add indexes needed for prompt lookup by word sense/status and weekly speaking summary queries by device/user and occurred-at.
- [x] 2.6 Update migration verification scripts to include the new speaking prompt/event tables and required indexes.

## 3. Backend API And Store Logic

- [x] 3.1 Extend learning-card or vocabulary response mapping to include approved speaking prompt data when available.
- [x] 3.2 Preserve fallback behavior when no approved speaking prompt exists, so existing card loading remains valid.
- [x] 3.3 Extend `POST /v1/study-events/sync` to accept a discriminated union of rating events and speaking events.
- [x] 3.4 Keep existing `POST /v1/study-events` single-rating behavior unchanged for current mobile rating flows.
- [x] 3.5 Persist speaking events separately from rating `study_events` so speaking events do not affect review scheduling or proficiency.
- [x] 3.6 Reject or strip raw audio bytes and local audio file paths from speaking event payloads.
- [x] 3.7 Return accepted, duplicate, and rejected event keys for mixed rating/speaking batches without failing the whole batch.
- [x] 3.8 Add a weekly speaking summary query for spoken sentence count, retry count, self-rating counts, approximate duration, and latest speaking timestamp.
- [x] 3.9 Add backend tests for valid speaking events, invalid event types, duplicate speaking events, mixed batch behavior, no-audio constraints, and no proficiency changes from speaking events.

## 4. Dashboard Prompt Review

- [x] 4.1 Add backend admin handlers or extend existing admin handlers for listing, editing, approving, and rejecting speaking prompts.
- [x] 4.2 Extend `expat8-dashboard` vocabulary/article review screens to display speaking prompt fields beside the related vocabulary item.
- [x] 4.3 Add prompt editing controls for target text, Vietnamese hint, target phrase, pronunciation tip, common mistake, difficulty, topic, and status.
- [x] 4.4 Add a prompt quality queue that filters prompts awaiting review or missing required speaking fields.
- [x] 4.5 Ensure all prompt mutations use existing app credential and admin token authentication.
- [x] 4.6 Add dashboard tests or build verification covering prompt review pages and mutation request shapes.

## 5. Mobile Local Data And Audio Infrastructure

- [x] 5.1 Evaluate and select a Flutter audio recording/playback plugin compatible with current Android/iOS targets.
- [x] 5.2 Add microphone permission declarations and a recoverable permission request flow that only appears when recording starts.
- [x] 5.3 Add a mobile audio recorder/playback service abstraction so UI and repository code do not depend directly on plugin APIs.
- [x] 5.4 Add local ObjectBox entities or fields for speaking prompt cache, speaking attempt metadata, retry count, self-rating, sync status, and local audio reference.
- [x] 5.5 Update ObjectBox generated files after entity changes.
- [x] 5.6 Implement local audio file naming, storage location, cleanup hooks, and delete-one/delete-all controls.
- [x] 5.7 Ensure local audio paths never enter backend API payloads or mobile logs.

## 6. Mobile Speaking Card Experience

- [x] 6.1 Extend vocabulary card models to carry optional speaking prompt data with fallback to existing example sentence when no prompt is available.
- [x] 6.2 Add optional speaking entry point to vocabulary cards without changing horizontal/vertical swipe behavior.
- [x] 6.3 Implement the speaking panel with target sentence, Vietnamese hint, record control, playback control, retry control, and self-rating choices.
- [x] 6.4 Persist `speaking_prompt_viewed`, `speaking_sample_played`, `speaking_recorded`, `speaking_retried`, and self-rating events locally.
- [x] 6.5 Queue speaking events for background sync and keep learning navigation available while sync is pending.
- [x] 6.6 Add encouraging completion copy that reports spoken sentence count, speaking time, and retry effort without harsh scoring.
- [x] 6.7 Add mobile tests for permission denial, local recording metadata, retry handling, self-rating, offline event queueing, and no blocking swipe navigation.

## 7. Mobile 3-Minute Speaking Drill

- [x] 7.1 Add drill selection logic that chooses up to five cached prompts from recently learned, due review, or useful phrase cards.
- [x] 7.2 Add drill UI with progress, prompt display, listen/read cue, record, retry, and self-rate steps.
- [x] 7.3 Add drill summary with spoken sentence count, retry count, self-rating counts, and approximate speaking duration.
- [x] 7.4 Handle insufficient cached prompts by starting with available prompts or showing a useful empty state.
- [x] 7.5 Add tests for drill selection, offline availability, progress handling, summary values, and empty-state behavior.

## 8. Privacy, Retention, And Analytics

- [x] 8.1 Implement local retention cleanup for speaking audio older than the configured retention window.
- [x] 8.2 Add UI copy that explains recordings are private and local-only in phase 0-3.
- [x] 8.3 Add local controls to delete one recording and delete all local speaking recordings.
- [x] 8.4 Add analytics events for first recording conversion, speaking prompt viewed, sample played, recorded, retried, self-rated, and drill completed.
- [x] 8.5 Add backend/mobile wiring for weekly speaking summary display.
- [x] 8.6 Verify no backend logs, dashboard logs, or mobile logs contain raw audio payloads or local audio file paths.

## 9. Verification And Release Readiness

- [x] 9.1 Run focused backend tests for speaking prompt and speaking event behavior.
- [x] 9.2 Run full backend test suite with `cd backend && npm test`.
- [x] 9.3 Run backend migration verification with `cd backend && npm run verify:migrations` after updating migration checks.
- [x] 9.4 Run focused mobile tests for speaking card, local audio service, local storage, sync queue, and drill behavior.
- [x] 9.5 Run full mobile test suite with `cd mobile && flutter test`.
- [x] 9.6 Run mobile ObjectBox code generation if entity changes were made.
- [x] 9.7 Run dashboard build/test verification for prompt review UI.
- [x] 9.8 Smoke test signed study-event sync for mixed rating/speaking batches against a local or dev backend.
- [x] 9.9 Update release notes and beta rollout documentation with feature flag, privacy behavior, and known limitations.
