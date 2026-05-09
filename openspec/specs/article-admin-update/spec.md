## ADDED Requirements

### Requirement: Admin can update article metadata
The system SHALL expose `PATCH /v1/admin/articles/:id` allowing admins to update a whitelist of article metadata fields: `title`, `language`, `visibility`, and `status`. Fields not in the whitelist SHALL be silently ignored. The endpoint requires the `X-Expat8-Admin-Token` header.

#### Scenario: Admin updates article title
- **WHEN** an admin sends `PATCH /v1/admin/articles/:id` with `{ "title": "New Title" }`
- **THEN** the response is `200` with the updated article and the new `title`

#### Scenario: Admin updates visibility to published
- **WHEN** an admin sends `PATCH /v1/admin/articles/:id` with `{ "visibility": "published" }`
- **THEN** the response is `200` and the article is now visible to all authenticated users

#### Scenario: Unknown fields are ignored
- **WHEN** an admin sends `PATCH /v1/admin/articles/:id` with `{ "raw_text": "..." }`
- **THEN** the response is `200` and `raw_text` is unchanged

#### Scenario: Patching a non-existent article returns 404
- **WHEN** an admin sends `PATCH /v1/admin/articles/:id` for an article ID that does not exist
- **THEN** the response is `404 { "error": "not_found" }`

#### Scenario: Request without admin token is rejected
- **WHEN** `PATCH /v1/admin/articles/:id` is called without the `X-Expat8-Admin-Token` header
- **THEN** the response is `403 { "error": "forbidden" }`

#### Scenario: Invalid visibility value is rejected
- **WHEN** an admin sends `{ "visibility": "secret" }` (not in allowed set)
- **THEN** the response is `400 { "error": "bad_request" }`
