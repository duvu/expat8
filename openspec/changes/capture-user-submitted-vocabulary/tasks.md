## 1. Backend contract and schema

- [x] 1.1 Add canonical API documentation for submitted vocabulary endpoints, request/response fields, and status lifecycle in `contracts/api.md`
- [x] 1.2 Add database schema + migration for user-submitted vocabulary records and processing jobs, including owner scope, normalized-term dedupe keys, status fields, failure reason, and resolved word linkage
- [x] 1.3 Run `cd backend && npm run verify:migrations` and confirm the new migration is accepted

## 2. Backend API and store logic

- [x] 2.1 Add store methods for creating/listing submitted vocabulary records, deduplicating by owner/language/normalized term, and linking to existing canonical words
- [x] 2.2 Add mobile API route(s) for creating a submitted term and listing current submission statuses using the existing signed-request + optional bearer-session model
- [x] 2.3 Add request validation and response shaping for supported language values, duplicate submissions, ready/existing resolutions, and failed statuses

## 3. Backend enrichment worker

- [x] 3.1 Add a dedicated single-term enrichment path that generates one canonical vocabulary item using the existing validation/persistence contract and `generation_source=user_submission`
- [x] 3.2 Extend the worker process to claim/process submitted-word jobs, persist ready words canonically, and mark failed jobs with learner-visible reasons
- [x] 3.3 Add backend tests covering create, list, duplicate submission reuse, existing-word linking, successful enrichment, and failure/retry behavior
- [x] 3.4 Run `cd backend && npm test` and confirm the backend test suite passes

## 4. Mobile data and local persistence

- [x] 4.1 Add mobile API client models/methods for creating submitted terms and fetching submission status records
- [x] 4.2 Add ObjectBox entity/entities and local database methods for captured-word records plus any new sync-queue entry types needed for offline upload/status refresh
- [x] 4.3 Add repository/service logic to queue local submissions, sync them to backend, poll status updates, and import ready resolved words into the standard local vocabulary store
- [x] 4.4 Run `cd mobile && flutter pub run build_runner build --delete-conflicting-outputs` after ObjectBox entity changes

## 5. Mobile UI flow

- [x] 5.1 Add a learner-facing capture entry point from the main vocabulary experience (for example via the existing drawer or a top-level action) with active-language defaulting
- [x] 5.2 Build the manual word-capture screen/form and submission list/status UI for queued, processing, ready, and failed entries
- [x] 5.3 Show learner feedback when a submission resolves to an existing word or a newly enriched ready word, and ensure ready words appear in the standard local study inventory

## 6. Verification and consistency

- [x] 6.1 Add/extend mobile tests for offline queueing, successful submission sync, ready-word import, and failed-status display
- [x] 6.2 Run `cd mobile && flutter test` and confirm the relevant mobile test suite passes
- [x] 6.3 Review current developer docs touched by the new API/status lifecycle and update any current-source references needed for cross-project consistency
