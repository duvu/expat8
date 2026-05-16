## ADDED Requirements

### Requirement: Backend provides workplace sentence feed
The backend SHALL provide a read-only API endpoint that returns prepared workplace sentence items for mobile bootstrap and refill, and SHALL NOT generate sentence content inline during feed requests.

#### Scenario: Mobile requests a sentence batch
- **WHEN** the mobile app requests workplace sentence items with learner context, target language, and limit
- **THEN** the backend returns stored eligible sentence items up to the requested limit without triggering sentence generation in the request path

#### Scenario: Stored sentence inventory is insufficient
- **WHEN** fewer eligible stored sentence items exist than the mobile app requested
- **THEN** the backend returns the available stored items in a successful response without performing inline generation

### Requirement: Backend stores normalized workplace sentence records
The backend SHALL persist workplace sentence items with stable identifiers, normalized English text, Vietnamese meaning, optional topic or source metadata, generation source, and timestamps.

#### Scenario: Article-derived sentence is persisted
- **WHEN** a workplace sentence candidate passes validation and is accepted for learner use
- **THEN** the backend stores the sentence record together with source article metadata and generation provenance

#### Scenario: Duplicate sentence is detected
- **WHEN** a workplace sentence candidate has the same normalized English text and language as an existing sentence record
- **THEN** the backend avoids creating a duplicate learner-facing sentence record

### Requirement: Backend serves only publishable sentence content
The backend SHALL return workplace sentence items only when their source content passed processing validation and, when linked to an article, the source article is published.

#### Scenario: Source article is not published
- **WHEN** a stored workplace sentence candidate is linked to an article that is still private, pending, or rejected
- **THEN** the backend excludes that sentence from the learner-facing sentence feed
