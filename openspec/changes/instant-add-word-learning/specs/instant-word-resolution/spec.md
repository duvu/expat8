## ADDED Requirements

### Requirement: Add word resolves in a single backend request
The system SHALL resolve a learner-submitted word in the same `POST /v1/user-submitted-words` request. If a canonical word already exists for the normalized term and language, the backend SHALL return that word immediately. If no canonical word exists, the backend SHALL generate the word through the AI enrichment path during the request, persist it canonically, and return the ready word in the same response.

#### Scenario: Submitted term already exists canonically
- **WHEN** the learner submits a term whose normalized term and language already match a canonical stored word
- **THEN** the backend returns a ready response with `resolution_type = "existing_word"` and the resolved word payload without queuing worker processing

#### Scenario: Submitted term requires AI generation
- **WHEN** the learner submits a term whose normalized term and language do not match any canonical stored word
- **THEN** the backend generates the word in-request, persists it canonically, and returns a ready response with `resolution_type = "generated_word"` and the resolved word payload

#### Scenario: AI generation cannot produce a valid word
- **WHEN** the learner submits a term and in-request AI generation fails validation or times out
- **THEN** the backend returns a failure response for that submission without leaving it in a learner-visible queued or processing state

### Requirement: Immediate resolution records a learner-owned capture outcome
The system SHALL still persist a learner-owned add-word record for history and deduplication, but that record SHALL be terminal immediately after the request completes.

#### Scenario: Existing-word resolution is persisted
- **WHEN** an add-word request resolves to an existing canonical word
- **THEN** the backend stores a learner-owned record with terminal ready status, links it to the canonical word, and records the resolution timestamp

#### Scenario: Generated-word resolution is persisted
- **WHEN** an add-word request generates a new canonical word successfully
- **THEN** the backend stores a learner-owned record with terminal ready status, links it to the generated canonical word, and records the resolution timestamp
