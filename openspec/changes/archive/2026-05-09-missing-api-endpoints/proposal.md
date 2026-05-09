## Why

`docs/architecture.md` defines several API endpoints that are documented as part of the system contract but are not yet implemented in `backend/src/app.js`. Users cannot get their own profile, delete articles they uploaded, inspect vocabulary extracted from an article, or use a readiness probe — all of which are required for the mobile app's article workflow and for operational reliability.

## What Changes

- Add `GET /health/ready` — DB-aware readiness probe used by load balancers and Docker health checks
- Add `GET /v1/me` — returns the current authenticated user's profile (requires Bearer session)
- Add `GET /v1/articles/:id/vocabulary` — returns the vocabulary items (`word_senses` + `terms`) extracted from a user-owned or published article
- Add `DELETE /v1/articles/:id` — soft-deletes (hides) a user-owned article
- Add `PATCH /v1/admin/articles/:id` — allows admins to update article metadata (title, language, visibility, target level)
- Update `docs/architecture.md` section 6.2 sync response example to match actual field names (`accepted_event_ids`, `rejected_events`, `duplicates`) instead of the stale `accepted`/`rejected` names

## Capabilities

### New Capabilities

- `user-profile`: Authenticated endpoint returning the current user's id, identifier, and display name
- `article-vocabulary`: Endpoint exposing vocabulary items extracted from a specific article (terms + senses), respecting ownership and visibility rules
- `article-deletion`: Soft-delete of user-owned articles; prevents further processing and hides from list endpoints
- `article-admin-update`: Admin patch endpoint for updating article metadata fields
- `backend-readiness-probe`: `/health/ready` endpoint that verifies DB connectivity before reporting healthy

### Modified Capabilities

- `study-events-api`: Sync response field names changed — `accepted` → `accepted_event_ids`, `rejected` → `rejected_events`, new `duplicates` field added

## Impact

- `backend/src/app.js` — five new route handlers
- `backend/src/word_store.js` — three new store methods (`getArticleVocabulary`, `softDeleteArticle`, `getMe`)
- `backend/src/postgres_word_store.js` — same three methods with SQL implementations
- `openspec/specs/study-events-api/` — delta spec to record the field name change
- `docs/architecture.md` — section 6.2 sync response example corrected
