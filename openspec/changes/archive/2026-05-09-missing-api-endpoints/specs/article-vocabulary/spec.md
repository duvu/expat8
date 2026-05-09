## ADDED Requirements

### Requirement: Authenticated user can retrieve vocabulary extracted from an article
The system SHALL expose `GET /v1/articles/:id/vocabulary` that returns the vocabulary items (`terms` + `word_senses`) extracted from a specific article. Access is granted to the article's owner or to any authenticated user if the article's visibility is `published`.

#### Scenario: Owner retrieves vocabulary from own private article
- **WHEN** an authenticated user requests `GET /v1/articles/:id/vocabulary` for an article they own
- **THEN** the response is `200` with `{ article_id, items: [{ term_id, display_term, word_sense_id, meaning_vi, part_of_speech, ipa, level, status }] }`

#### Scenario: Any authenticated user retrieves vocabulary from a published article
- **WHEN** an authenticated user requests `GET /v1/articles/:id/vocabulary` for an article with `visibility = 'published'`
- **THEN** the response is `200` with the vocabulary items for that article

#### Scenario: Non-owner cannot access private article vocabulary
- **WHEN** an authenticated user requests vocabulary for an article they do not own and which is not `published`
- **THEN** the response is `404 { "error": "not_found" }`

#### Scenario: Unauthenticated request is rejected
- **WHEN** a request is made without a valid Bearer session
- **THEN** the response is `401 { "error": "invalid_session" }`

#### Scenario: Article with no vocabulary yet returns empty items
- **WHEN** an article is in `pending_processing` or `processing` status and has no `article_terms` yet
- **THEN** the response is `200` with `{ article_id, items: [] }`

#### Scenario: Only approved word senses are included for published articles
- **WHEN** an article is `published` and some extracted `word_senses` have `status = 'pending_review'`
- **THEN** only senses with `status = 'approved'` SHALL be returned
