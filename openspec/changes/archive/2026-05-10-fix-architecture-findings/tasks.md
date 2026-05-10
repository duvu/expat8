## 1. Speaking Events — attempt_id (Backend)

- [x] 1.1 In `word_store.js` `normalizeSpeakingEvent`: make `attempt_id` optional (store `null` when absent) to support the transition window
- [x] 1.2 In `postgres_word_store.js`: same change — accept and persist `attempt_id = null` when field is absent
- [x] 1.3 Add a config flag (`SPEAKING_EVENTS_STRICT_ATTEMPT_ID`, default `false`) in `config.js` to control whether missing `attempt_id` is rejected or silently accepted
- [x] 1.4 Apply strict-mode check in both stores: when flag is `true`, reject events missing `attempt_id` with `400 missing_required_field`
- [x] 1.5 Write backend unit test: event with `attempt_id` is accepted; event without `attempt_id` is accepted in lenient mode and rejected in strict mode

## 2. Speaking Events — attempt_id (Mobile)

- [x] 2.1 In `speaking_repository.dart`: generate a UUID v4 (`const Uuid().v4()`) before the drill starts and store it as `_currentAttemptId`
- [x] 2.2 Attach `attempt_id: _currentAttemptId` to every speaking event payload in `onDrillCompleted`, `onPromptViewed`, `onSamplePlayed`, and any other event methods in `speaking_repository.dart`
- [x] 2.3 Clear `_currentAttemptId` after `onDrillCompleted` is called
- [x] 2.4 Run `flutter test` to confirm no regressions

## 3. SRS Card Selection (Backend)

- [x] 3.1 Confirm the `next_review_at` field location in the Postgres schema (check migrations or `postgres_word_store.js` for table/column name)
- [x] 3.2 In `WordStore.learningCards` (`word_store.js:220-251`): add a query step that collects in-memory review items where `next_review_at ≤ Date.now()`; return up to `floor(count * 0.85)` as review cards and fill remainder with new cards
- [x] 3.3 In `PostgresWordStore.learningCards` (`postgres_word_store.js:343-383`): add a SQL query selecting review items where `next_review_at <= NOW()` ordered by `next_review_at ASC`; apply 85/15 split; remove hardcoded `review: 0` filter
- [x] 3.4 Add partial index `CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_review_items_due ON review_items(next_review_at) WHERE next_review_at IS NOT NULL` (add as a migration or inline migration check)
- [x] 3.5 Ensure review card response items include `card_type: "review"` and `word_sense_id`
- [x] 3.6 Write backend unit test: with mix of due and non-due items, response has correct 85/15 ratio and correct `card_type` values

## 4. Article Reprocessing Safety (Backend)

- [x] 4.1 In `WordStore.reprocessArticle` (`word_store.js:652`): before re-enqueueing, delete all `article_terms`, `word_senses`, and `review_items` entries belonging to the article from the in-memory store
- [x] 4.2 In `PostgresWordStore`: wrap the delete-then-insert in `persistArticleVocabulary` in a single database transaction; delete `article_terms`, `word_senses`, and `review_items` for the article before inserting new records
- [x] 4.3 Add `FOR UPDATE` lock on the article row when entering a reprocess to prevent concurrent double-deletes
- [x] 4.4 Write backend test: reprocess the same article twice; assert vocabulary count equals single-process count

## 5. Vocabulary Fallback Quality Gate (Backend)

- [x] 5.1 In `VocabularyEnrichmentAdapter.#fallbackSuggestions` (`vocabulary_enrichment_adapter.js`): add `isStub: true` to each generated item object
- [x] 5.2 In `persistArticleVocabulary` (both stores): when an item has `isStub: true`, set `approved = false` unconditionally (skip the admin-upload auto-approval branch)
- [x] 5.3 Write backend test: admin-uploaded article that falls back to stubs has all vocabulary with `approved = false`; admin-uploaded article with LLM enrichment has `approved = true`

## 6. Speaking Prompt Field Name Fix (Mobile)

- [x] 6.1 In `backend_api_client.dart` `SpeakingPromptItem.fromJson` (~line 1133): change `json['pronunciation_tip_vi']` → `json['pronunciation_tip']` and `json['common_mistake_vi']` → `json['common_mistake']`
- [x] 6.2 Run `flutter test` to confirm deserialization is correct

## 7. Speaking Prompt Lifecycle (Mobile)

- [x] 7.1 In `speaking_prompt_sync_service.dart`: expose a public `sync()` method (or rename `syncIfNeeded` to be callable from lifecycle handler)
- [x] 7.2 In `main.dart` (or the app widget's lifecycle mixin): call `SpeakingPromptSyncService.sync()` in the `AppLifecycleState.resumed` handler
- [x] 7.3 In `local_database.dart` `upsertAllSpeakingPrompts` (~line 1026): after upserting received prompts, query all local prompt IDs for this user and delete any whose `promptId` is not in the received set
- [x] 7.4 Run `flutter test` to confirm stale-prompt deletion logic works correctly

## 8. wordSenseId Mapping in Sync (Mobile)

- [x] 8.1 In `speaking_repository.dart` `upsertAllFromSync` (~line 106): replace `wordSenseId: null` with `wordSenseId: item['word_sense_id'] as String?` (or equivalent typed accessor)
- [x] 8.2 Write a test (or inspect manually): after sync, `getByWordSenseId` returns the prompt for a known `word_sense_id`

## 9. Drill Attempt Counter Fix (Mobile)

- [x] 9.1 In `speaking_drill_screen.dart` `_onPromptComplete`: move the `_totalAttempts++` increment to occur before reading `_totalAttempts` in the `onDrillCompleted` call, OR restructure so the increment happens after the callback only for non-final prompts
- [x] 9.2 Verify the fix: a drill with 3 prompts reports `promptsAttempted: 3` (not 4)

## 10. Shared Visibility Removal (Backend)

- [x] 10.1 In `app.js` line 416 (article creation validation): remove `'shared'` from the accepted visibility values array
- [x] 10.2 In `app.js` line 972 (article update validation): remove `'shared'` from the accepted visibility values array
- [x] 10.3 Update `contracts/api.md`: document that valid visibility values are `'private'` and `'published'` only
- [x] 10.4 Write backend test: POST/PATCH with `visibility: "shared"` returns `400`

## 11. Verification

- [x] 11.1 Run `cd backend && npm test` — all tests pass
- [x] 11.2 Run `cd mobile && flutter test` — all tests pass
- [x] 11.3 Manual smoke test on local stack: submit a speaking drill → events accepted; request learning cards → review cards present; reprocess an article → no duplicate vocabulary
