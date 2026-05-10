## ADDED Requirements

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
