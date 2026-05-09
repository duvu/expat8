## ADDED Requirements

### Requirement: Authenticated user can soft-delete own article
The system SHALL expose `DELETE /v1/articles/:id` that sets the article's `status` to `'deleted'` and `visibility` to `'private'`. This hides the article from list and vocabulary endpoints. Extracted vocabulary is preserved. Only the article's owner may delete it.

#### Scenario: Owner deletes own article
- **WHEN** an authenticated user sends `DELETE /v1/articles/:id` for an article they own
- **THEN** the response is `200 { "success": true }` and the article is no longer returned by `GET /v1/articles`

#### Scenario: Deleted article is excluded from list
- **WHEN** `GET /v1/articles` is called after an article has been deleted
- **THEN** the deleted article SHALL NOT appear in `items`

#### Scenario: Deleted article vocabulary is inaccessible
- **WHEN** `GET /v1/articles/:id/vocabulary` is called for a deleted article
- **THEN** the response is `404 { "error": "not_found" }`

#### Scenario: Non-owner cannot delete article
- **WHEN** an authenticated user sends `DELETE /v1/articles/:id` for an article they do not own
- **THEN** the response is `404 { "error": "not_found" }`

#### Scenario: Missing session is rejected
- **WHEN** `DELETE /v1/articles/:id` is called without a valid Bearer session
- **THEN** the response is `401 { "error": "invalid_session" }`
