## Context

The current expat8 vocabulary flow assumes that new words enter the system either through seeded content, article ingestion, or existing backend generation. The mobile app starts on `LearningScreen`, keeps a local ObjectBox cache, and already persists retryable sync work such as study events and speaking uploads. The backend already has a worker process and validation/persistence rules for vocabulary items, but it does not have any API or data model for a learner to submit an unfamiliar word directly.

This change is cross-cutting:
- mobile needs a new learner-facing capture flow and local/offline queue behavior,
- backend needs new API, persistence, and ownership rules,
- the worker needs a new asynchronous enrichment job type,
- contracts/tests/docs must stay aligned so the new lifecycle is explicit across the project.

## Goals / Non-Goals

**Goals:**
- Let a learner type a new word (or short expression) into the mobile app and save it even if the device is temporarily offline.
- Process the submission asynchronously on the backend with AI so the resulting word record uses the same schema and validation as normal vocabulary items.
- Surface submission status (`pending`, `processing`, `ready`, `failed`, duplicate/existing resolution) back to the mobile app.
- Insert ready submissions into the standard `words` inventory and return a resolved word payload that mobile can store locally as a normal learning card.
- Keep API contracts, tests, docs, and status values consistent across mobile, backend, and worker flows.

**Non-Goals:**
- Manual editing or approval UI in the dashboard/admin app.
- Bulk import of word lists, OCR, camera scan, or article-level extraction from the mobile app.
- Synchronous LLM generation in the request path.
- A separate custom study mode for submitted words; ready words should reuse the normal learning pipeline.

## Decisions

### D1 — Use a dedicated submission resource instead of reusing articles
Introduce a new backend resource for user-submitted vocabulary (for example, `user_word_submissions` plus a corresponding job table) instead of creating synthetic `articles` or abusing the article-processing pipeline.

**Rationale:** a typed word has different ownership, lifecycle, retry semantics, and UX than article ingestion. A dedicated resource keeps the model explicit, avoids fake article rows, and makes status polling/test coverage straightforward.

**Alternative considered:** store each typed word as a one-line article and reuse `article_processing_jobs`. Rejected because it pollutes article tables, creates confusing status names, and couples a single-term use case to chunk-based article extraction.

### D2 — Reuse the existing worker container, but add a second job processor
Keep the current separate backend worker process and extend it to claim/process user-submitted-word jobs in addition to article jobs.

**Rationale:** deployment already runs a single `expat8-worker` container. Reusing that process minimizes operational change while preserving asynchronous enrichment outside request/response latency.

**Alternative considered:** introduce a second dedicated worker service just for submissions. Rejected for v1 because the expected volume is low and extra deployment complexity is not justified yet.

### D3 — Mobile stores submissions locally and retries upload through the existing outbox pattern
Add a local ObjectBox entity for captured words plus a sync-queue entry type for submission uploads/status refreshes.

**Rationale:** the app already follows an offline-first pattern for study activity. Requiring online-only word capture would be inconsistent with the rest of the mobile architecture and would lose learner intent when connectivity is unstable.

### D4 — Ready submissions return a resolved word payload matching the standard learning-card shape
When a submission reaches a terminal ready state, backend status responses should include the resolved word fields needed by mobile (`term`, `meaning_vi`, `ipa`, pronunciation, example, difficulty, topics, explanation, etc.). Mobile then upserts that word into the same local `LocalWordEntity` store used for normal refill cards.

**Rationale:** this preserves one canonical word model and avoids adding special card rendering logic or custom study paths.

**Alternative considered:** rely only on `/v1/learning/cards` to eventually surface the submitted word. Rejected because it delays learner feedback and makes the feature feel unreliable when the word gets mixed into the broader feed.

### D5 — Submission identity is owner-scoped and idempotent
Submissions are scoped to the signed-in user when a bearer session exists; otherwise they are scoped to the stable anonymous `device_id`. The backend normalizes `term + language + owner` to avoid creating duplicate pending submissions.

**Rationale:** expat8 already supports anonymous learning. The same device/user identity rules should apply here so learners can capture words before signing in without creating inconsistent duplicates.

### D6 — AI enrichment reuses the same validation and persistence contract as stored vocabulary
The enrichment step should call a dedicated single-term generation method but must still pass through the current vocabulary validation and persistence logic, using a `generation_source` such as `user_submission`.

**Rationale:** this keeps word quality fields and deduplication consistent with the rest of the project.

## Risks / Trade-offs

- [Risk] A submitted isolated term may lack enough context for high-quality AI output. → Mitigation: keep the required payload to a term for v1, but store explicit `failed` state and leave room for an optional context sentence in a future change.
- [Risk] The same normalized term may already exist globally but with a meaning the learner did not expect. → Mitigation: treat v1 as linking to the canonical existing word when present, rather than creating duplicate senses silently.
- [Risk] Offline queue + polling adds state complexity on mobile. → Mitigation: reuse the existing ObjectBox + sync queue pattern instead of inventing a second persistence mechanism.
- [Trade-off] Reusing the existing worker process keeps operations simple, but high submission volume could compete with article jobs. → Mitigation: separate claim methods and observability counters make it possible to split workers later if backlog grows.

## Migration Plan

1. Add backend schema migration(s) for user-submitted-word records and processing jobs.
2. Add API contract documentation and backend route/store/worker support.
3. Add mobile API client, ObjectBox entities, repository methods, and UI.
4. Regenerate ObjectBox code, run backend/mobile test suites, and verify the worker path locally.
5. Deploy backend + worker + mobile build in normal release cadence.

Rollback:
- Backend/worker rollback is safe by disabling the new route and worker claim path; new tables can remain unused.
- Mobile rollback removes the UI path; queued local submissions on downgraded clients are acceptable to abandon because they are not part of an external contract yet.

## Open Questions

- Should v1 allow short phrases/idioms in addition to single tokens, or restrict the UI copy to “word/expression” while still using one generic `term` field?
- Should the mobile app expose a manual “retry failed submission” action in v1, or is resubmitting the same term enough because the backend is idempotent by owner/language/term?
