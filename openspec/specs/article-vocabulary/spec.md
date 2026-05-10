## Requirements

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

### Requirement: Article vocabulary reprocessing is idempotent
When an article is reprocessed, the backend SHALL delete all previously extracted vocabulary (article terms, word senses, and review items) for that article before inserting the new enrichment results. The end state after reprocessing MUST be identical to the state after first processing.

#### Scenario: Article is reprocessed once
- **WHEN** an admin triggers reprocessing of an article that already has vocabulary
- **THEN** the prior vocabulary entries are removed and replaced with the newly enriched vocabulary, resulting in no duplicates

#### Scenario: Article is reprocessed multiple times
- **WHEN** an article is reprocessed more than once
- **THEN** each reprocess yields the same vocabulary count as a single reprocess (no accumulation)

#### Scenario: Reprocess fails mid-operation
- **WHEN** vocabulary enrichment fails after the prior vocabulary has been deleted
- **THEN** the article retains no vocabulary (clean state) rather than a partial result, and the article status is set to an error state

### Requirement: Shared visibility is not accepted on article write paths
The article creation and update endpoints SHALL NOT accept `visibility = 'shared'` as a valid value. Requests supplying `'shared'` SHALL be rejected.

#### Scenario: Create article with shared visibility
- **WHEN** a client submits `POST /v1/articles` with `visibility: "shared"`
- **THEN** the backend responds `400 { "error": "invalid_visibility" }`

#### Scenario: Update article to shared visibility
- **WHEN** a client submits `PATCH /v1/articles/:id` with `visibility: "shared"`
- **THEN** the backend responds `400 { "error": "invalid_visibility" }`

