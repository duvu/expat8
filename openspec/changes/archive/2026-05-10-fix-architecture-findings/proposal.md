## Why

An architecture review identified ten bugs and structural gaps ranging from critical (speaking events rejected by the backend) to low severity (off-by-one in drill summary). Left unfixed, the most critical issues mean core product loops — speaking practice and spaced-repetition review — are entirely non-functional in production. The fixes are well-bounded and do not require schema migrations beyond in-place query adjustments.

## What Changes

- **Speaking events**: mobile adds `attempt_id` to all speaking event payloads so the backend stops rejecting them with `missing_required_field`.
- **SRS card selection**: `learningCards` returns review cards (due items from prior study events) alongside new cards, making spaced repetition functional.
- **Article reprocessing safety**: `reprocessArticle` clears prior vocabulary before re-inserting; `persistArticleVocabulary` becomes idempotent via upsert/delete.
- **Vocabulary fallback quality**: fallback-generated vocabulary stubs are never auto-approved for learner-facing content; a quality gate blocks junk IPA and placeholder meanings.
- **Speaking prompt field alignment**: `SpeakingPromptItem.fromJson` reads `pronunciation_tip` / `common_mistake` (no `_vi` suffix) to match backend serialization.
- **Speaking prompt lifecycle**: sync runs on session resume (not only startup); `upsertAllSpeakingPrompts` deletes prompts absent from the server response.
- **`wordSenseId` in synced prompts**: `upsertAllFromSync` maps `word_sense_id` from the server payload instead of hardcoding `null`.
- **Drill attempt counter**: `_totalAttempts` increments after (not before) the `onDrillCompleted` callback to eliminate the off-by-one.
- **`shared` visibility**: remove `'shared'` from accepted visibility values in write paths until read semantics are defined, or define and implement those semantics.

## Capabilities

### New Capabilities

- `speaking-events`: Mobile speaking event submission contract — required fields (`attempt_id`), event types, and backend normalization rules.
- `srs-card-selection`: Algorithm and API contract for `learningCards` — how review cards are selected, the 85/15 review/new ratio, and due-card query logic.
- `speaking-prompt-lifecycle`: Speaking prompt sync contract — field names on wire, sync trigger points, stale-prompt removal, `word_sense_id` mapping.

### Modified Capabilities

- `article-vocabulary`: Idempotent reprocessing requirement — reprocess must clear prior vocabulary entries before inserting new ones.
- `ai-vocabulary-generation`: Fallback stub quality gate — stubs with placeholder IPA or empty meanings must not be auto-approved.

## Impact

- **Backend**: `word_store.js`, `postgres_word_store.js` (learningCards, persistArticleVocabulary, reprocessArticle, normalizeSpeakingEvent); `app.js` (visibility validation).
- **Mobile**: `speaking_repository.dart` (attempt_id, wordSenseId), `backend_api_client.dart` (SpeakingPromptItem field names), `speaking_prompt_sync_service.dart` (sync triggers), `local_database.dart` (stale-prompt deletion), `speaking_drill_screen.dart` (counter fix).
- **API contract**: `contracts/api.md` updated to reflect speaking event required fields and speaking prompt wire field names.
- **No new database migrations required** — all Postgres changes are query-level (upsert/delete within existing tables).
