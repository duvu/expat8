## 1. Store methods

- [x] 1.1 Add `getMe({ sessionToken })` to `WordStore` — returns `{ user_id, identifier, display_name }` from the session map
- [x] 1.2 Add `getMe({ sessionToken })` to `PostgresWordStore` — JOIN `user_sessions` + `users` on `token_hash`, return profile fields
- [x] 1.3 Add `getArticleVocabulary({ articleId, userId })` to `WordStore` — returns vocabulary items from `articleTermsById`/`wordSensesById`/`termsById`, enforcing ownership or published visibility
- [x] 1.4 Add `getArticleVocabulary({ articleId, userId })` to `PostgresWordStore` — single JOIN query across `articles`, `article_terms`, `word_senses`, `terms`; filter by ownership or visibility; filter `word_senses.status = 'approved'` for published articles
- [x] 1.5 Add `softDeleteArticle({ articleId, userId })` to `WordStore` — sets `status = 'deleted'`, `visibility = 'private'` on matching article; returns null if not found or not owned
- [x] 1.6 Add `softDeleteArticle({ articleId, userId })` to `PostgresWordStore` — UPDATE with ownership check, RETURNING `*`
- [x] 1.7 Add `patchAdminArticle({ articleId, patch })` to `WordStore` — applies whitelisted fields (`title`, `language`, `visibility`, `status`) to article; returns null if not found
- [x] 1.8 Add `patchAdminArticle({ articleId, patch })` to `PostgresWordStore` — dynamic UPDATE limited to whitelisted columns; returns null if no row matched

## 2. Route handlers

- [x] 2.1 Add `GET /health/ready` at app level (outside `/v1`) — calls `store.healthCheck()` (or equivalent) and returns `200 { ok, db }` or `503 { ok, db }`; add `healthCheck()` method to both stores
- [x] 2.2 Add `GET /v1/me` — calls `resolveRequiredUserSession`, returns `{ user_id, identifier, display_name }`
- [x] 2.3 Add `GET /v1/articles/:id/vocabulary` — calls `resolveRequiredUserSession`, calls `store.getArticleVocabulary`, returns `{ article_id, items }`
- [x] 2.4 Add `DELETE /v1/articles/:id` — calls `resolveRequiredUserSession`, calls `store.softDeleteArticle`, returns `200 { success: true }` or `404`
- [x] 2.5 Add `PATCH /v1/admin/articles/:id` — checks `hasAdminAccess`, validates patchable fields, calls `store.patchAdminArticle`, returns updated article or `404`

## 3. Tests

- [x] 3.1 Test `GET /v1/me` — valid session returns profile; invalid session returns 401
- [x] 3.2 Test `GET /v1/articles/:id/vocabulary` — owner sees vocabulary; published article accessible by others; private article returns 404 for non-owner; unauthenticated returns 401
- [x] 3.3 Test `DELETE /v1/articles/:id` — owner deletes successfully; deleted article absent from list; non-owner gets 404
- [x] 3.4 Test `PATCH /v1/admin/articles/:id` — admin patches title; unknown fields ignored; no admin token returns 403; article not found returns 404; invalid visibility returns 400
- [x] 3.5 Test `GET /health/ready` — responds without app credential headers; returns 200 when store is healthy

## 4. Documentation

- [x] 4.1 Update `docs/architecture.md` section 6.2 sync response example to use `accepted_event_ids`, `rejected_events`, `duplicates`
- [x] 4.2 Update `contracts/api.md` to document `GET /v1/me`, `GET /v1/articles/:id/vocabulary`, `DELETE /v1/articles/:id`, `PATCH /v1/admin/articles/:id`, and `GET /health/ready`
