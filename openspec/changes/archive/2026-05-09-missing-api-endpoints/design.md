## Context

`backend/src/app.js` currently implements 20 routes but leaves five documented endpoints absent. Both stores (`WordStore` in-memory and `PostgresWordStore`) must implement the same interface, so each new endpoint requires a method in both. The stores already have the article tables and vocabulary tables (`terms`, `word_senses`, `article_terms`, `vocabulary_review_items`) from the `content-ingestion-v2-foundation` migration.

The app uses a single `createApp({ store, config })` factory — all new routes follow the existing pattern of `asyncHandler` + optional/required session resolution + store method call.

## Goals / Non-Goals

**Goals:**
- Fill the five missing routes so the documented API contract matches the running server
- Maintain parity between `WordStore` (in-memory, used in tests) and `PostgresWordStore` (production)
- Update `docs/architecture.md` section 6.2 to match actual sync response field names
- Add tests for each new endpoint in `test/api.test.js`

**Non-Goals:**
- Pagination for vocabulary items (article vocabulary sets are bounded by article length)
- Hard-delete of articles or cascading delete of associated vocabulary
- Rate limiting for new endpoints (existing HMAC guard is sufficient for MVP)
- Admin editing of article raw text (only metadata fields)

## Decisions

**`GET /health/ready` lives at the app level, not inside `/v1`**
Architecture.md calls this `/ready` but the convention already established is a top-level `/health`. The readiness probe will be `GET /health/ready` — no app credentials required (same as `/health`). It queries `SELECT 1` against the pool to confirm DB connectivity. Alternative: a separate `/ready` path — rejected because it adds another CORS exception and the `/health` namespace already conveys intent.

**Article vocabulary respects ownership + visibility, not just ownership**
`GET /v1/articles/:id/vocabulary` requires an authenticated session. It returns vocabulary if: the requester owns the article, OR the article has `visibility = 'published'`. This allows other logged-in users to study vocabulary from published articles without needing to be the owner. Alternative: owner-only — rejected because published articles should be learnable by any signed-in user.

**`DELETE /v1/articles/:id` is a soft delete**
The article row gets `status = 'deleted'` and `visibility = 'private'`. Processing jobs are abandoned (not deleted). This is recoverable by admin and preserves the vocabulary already extracted. Alternative: hard delete with CASCADE — rejected because it destroys extracted vocabulary that may be shared across other articles via the `terms` table.

**`PATCH /v1/admin/articles/:id` uses a whitelist of patchable fields**
Only `title`, `language`, `visibility`, and `status` are patchable by admin. `raw_text` is not patchable (reprocess instead). Unknown keys in the request body are silently ignored. This avoids a generic update path that could corrupt processing state.

**`GET /v1/me` returns user + session metadata, no sensitive fields**
Returns `user_id`, `identifier`, `display_name`. Does not return `password_hash`, `token_hash`, or session expiry. Requires valid Bearer session. If the session is invalid, standard `401 invalid_session` applies.

## Risks / Trade-offs

- **`WordStore` soft-delete** is in-memory mutation of the article object; `PostgresWordStore` issues an UPDATE. The test store does not enforce referential consistency for `article_processing_jobs`, so abandoned jobs stay in `pending_processing` state — acceptable for tests.
- **Vocabulary endpoint N+1** — `PostgresWordStore.getArticleVocabulary` should JOIN `terms`, `word_senses`, and `article_terms` in a single query rather than issuing one query per term. The in-memory store can iterate maps.
- **`/health/ready` under load** — a synchronous `SELECT 1` on every readiness probe is cheap but adds DB load if the probe interval is very short. Mitigation: document that the probe interval should be ≥ 10s.

## Migration Plan

All new endpoints are additive — no schema changes, no data migrations. Deploy the backend and the new routes are immediately live. Rollback is a code revert; no DB state is affected.

## Open Questions

- Should `DELETE /v1/articles/:id` also cancel in-flight `processing` jobs (set them to `cancelled` status)? Current plan: no — jobs complete and write results, but the article stays `deleted` so the vocabulary is `pending_review` regardless.
- Should published-article vocabulary be visible to anonymous (unauthenticated) callers? Current plan: no — require Bearer session for all `/v1/articles/:id/vocabulary` calls.
