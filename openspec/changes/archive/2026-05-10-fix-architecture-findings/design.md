## Context

The expat8 backend exposes a Node.js 22 + Express API backed by either an in-memory `WordStore` (dev) or `PostgresWordStore` (production). The Flutter mobile client communicates via signed REST requests and maintains an ObjectBox local database for offline-first operation. An architecture review surfaced ten bugs spanning the full stack: the most severe prevent speaking events from reaching the backend and make spaced-repetition card selection return only new cards, rendering both core learning loops non-functional in production.

All fixes operate within existing tables and API routes; no new infrastructure is required.

## Goals / Non-Goals

**Goals:**
- Make speaking drill events accepted and persisted by the backend (add `attempt_id` to mobile payloads).
- Make `learningCards` return due review cards per the documented 85 review / 15 new ratio.
- Make article reprocessing idempotent (no duplicate vocabulary on reprocess).
- Gate fallback vocabulary stubs from auto-approval for learners.
- Align `SpeakingPromptItem` field names between backend serialization and mobile deserialization.
- Improve speaking prompt sync: refresh on resume, delete stale prompts, map `word_sense_id`.
- Fix `_totalAttempts` off-by-one in drill summary.
- Clarify `shared` visibility: either remove it from accepted values or define its read semantics.

**Non-Goals:**
- Refactoring `WordStore` / `PostgresWordStore` to share a common interface (tracked separately as a maintenance concern).
- Adding OpenAPI/code-generated contract validation (a future hardening task).
- Any new article-processing features beyond quality gates on fallback stubs.
- Changing the article processing worker's concurrency model.

## Decisions

### D1 — Speaking events: client generates `attempt_id` (UUID v4)

**Decision**: Mobile generates a UUID v4 as `attempt_id` before starting a drill and attaches it to every speaking event emitted during that drill session.

**Rationale**: The backend `normalizeSpeakingEvent` already requires `attempt_id`; the simplest fix is to have the client own the attempt boundary since a drill session is inherently client-initiated. Generating server-side would require a new round-trip before the drill can start.

**Alternative considered**: Add a `POST /v1/speaking/attempts` endpoint to obtain a server-issued ID. Rejected — extra latency and unnecessary complexity for a value that is only used for grouping events.

---

### D2 — SRS card selection: query `study_events` for due items

**Decision**: `learningCards` queries existing `study_events` / `review_items` tables to find items whose `next_review_at` ≤ now, returns up to 85% of the requested count as review cards, and fills the remainder with new cards.

**Rationale**: The data model already captures `next_review_at` via the rating system (`study-event-rating-system` spec). No schema changes are needed — only the query logic in `WordStore.learningCards` and `PostgresWordStore.learningCards` changes.

**Alternative considered**: Separate endpoint for review cards. Rejected — the existing `/v1/learning/cards` contract is what the mobile uses; changing the endpoint would require a coordinated mobile release.

---

### D3 — Article reprocessing: delete-then-insert per article

**Decision**: `reprocessArticle` (both stores) deletes all `article_terms`, `word_senses`, and `review_items` rows for the given article before re-running enrichment and calling `persistArticleVocabulary`. `persistArticleVocabulary` in Postgres uses `INSERT … ON CONFLICT DO UPDATE` for word-level data that is shared across articles (e.g., `words` table) but always deletes article-scoped rows first.

**Rationale**: Clean slate avoids accumulation of stale senses. The enrichment pipeline is deterministic given the same article text, so re-insertion produces the same vocabulary set.

**Risk**: If enrichment fails mid-reprocess, the article temporarily has no vocabulary. Mitigated by wrapping delete + insert in a database transaction (Postgres) or an atomic replace in the in-memory store.

---

### D4 — Fallback vocabulary: `approved = false` always; no auto-approval for stubs

**Decision**: Any vocabulary item produced by `#fallbackSuggestions` in `VocabularyEnrichmentAdapter` is inserted with `approved = false` regardless of upload source. Admin review is required before stubs reach learners.

**Rationale**: Fallback stubs contain placeholder IPA `/na/` and fabricated meanings that degrade learning quality. The existing auto-approval path (for admin-uploaded articles) assumes LLM-enriched quality; stubs do not meet that bar.

**Implementation**: Add a `isStub: true` flag to fallback-generated items. In `persistArticleVocabulary`, set `approved = false` when `isStub` is true, bypassing the admin-upload auto-approval logic.

---

### D5 — Speaking prompt field names: fix mobile `fromJson`, keep backend unchanged

**Decision**: Change `SpeakingPromptItem.fromJson` in `backend_api_client.dart` to read `pronunciation_tip` and `common_mistake` (no `_vi` suffix). Do not change the backend serialization.

**Rationale**: The backend field names are the correct canonical names (no language suffix makes sense for a single-language backend). The mobile was wrong to add `_vi`. Changing the mobile is a one-line fix with no API contract impact.

---

### D6 — Speaking prompt sync: trigger on app resume; delete absent prompts

**Decision**: `SpeakingPromptSyncService.syncIfNeeded` is called from the app lifecycle `resumed` handler in addition to startup. `upsertAllSpeakingPrompts` in `local_database.dart` deletes all local prompts whose `promptId` is not in the server response set.

**Rationale**: Startup-only sync means a long-lived session uses stale prompts. Delete-absent ensures revoked prompts are removed — currently they persist indefinitely.

---

### D7 — `wordSenseId` mapping: read `word_sense_id` from server payload

**Decision**: `upsertAllFromSync` in `speaking_repository.dart` maps `item['word_sense_id']` (or the equivalent field from the backend response) to `wordSenseId` instead of hardcoding `null`.

**Rationale**: Backend speaking prompts include `word_sense_id` in the response (confirmed in `postgres_word_store.js`). The field was simply not being read.

---

### D8 — `shared` visibility: remove from accepted values (clean removal)

**Decision**: Remove `'shared'` from the accepted visibility enum in `app.js` validation (lines 416, 972). Any existing rows with `visibility = 'shared'` are treated as `'private'` in all read paths (no migration needed since no read path ever honored `'shared'`).

**Rationale**: Undefined semantics in a write path create a false sense of functionality. Removing it now avoids future confusion. If sharing semantics are desired, they should be designed as a new capability.

## Risks / Trade-offs

- **[Risk] Drill sessions mid-upgrade lack `attempt_id`**: If the mobile app is updated server-side before mobile release, old clients continue sending events without `attempt_id` and events are rejected. → Mitigation: backend temporarily accepts events without `attempt_id` (treat as `null`) during the transition window; re-tighten after old app versions are deprecated.
- **[Risk] Reprocess transaction atomicity (Postgres)**: Delete + insert must be atomic. If a reprocess is triggered concurrently, two workers could double-delete. → Mitigation: article processing worker already processes one article at a time per the existing design; add a DB-level `FOR UPDATE` lock on the article row during reprocess.
- **[Risk] SRS review card query performance**: Querying `study_events` for due items without an index on `next_review_at` will be slow at scale. → Mitigation: add a partial index on `review_items(next_review_at) WHERE next_review_at IS NOT NULL` as part of this change.
- **[Trade-off] Fallback stubs blocked from learners**: Articles that fail LLM enrichment will have no vocabulary for learners until an admin approves stubs. This is intentional — quality over availability.

## Migration Plan

1. **Backend deploy first**: Deploy new backend with `attempt_id` optional (not required) for speaking events, new `learningCards` query, idempotent reprocessing, fallback quality gate, `shared` visibility removal.
2. **Mobile release**: Release updated Flutter app with `attempt_id` generation, field name fixes, sync improvements.
3. **Tighten backend**: After old mobile versions drop below threshold, re-enable strict `attempt_id` requirement.
4. **Rollback**: Each fix is independently deployable. Backend rollback is a container image swap. Mobile rollback requires a new Play Store release (or force-upgrade mechanism).

## Open Questions

- What is the correct `next_review_at` computation when a `study_event` is submitted? (Confirm against `study-event-rating-system` spec before implementing D2.)
- Should `shared` visibility be a planned future capability (requires design) or permanently removed?
