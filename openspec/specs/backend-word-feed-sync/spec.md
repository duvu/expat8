## ADDED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns new vocabulary items for the mobile app.

#### Scenario: Mobile requests a new word
- **WHEN** the mobile app calls the new-word feed endpoint with source language, target language, mode, and limit
- **THEN** the backend returns vocabulary items matching the request parameters

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a new-word request
- **THEN** the backend can return stored words without calling AI generation

### Requirement: Backend stores vocabulary records
The backend SHALL persist generated or accepted vocabulary items with the fields required by the mobile learning card.

#### Scenario: Word is persisted
- **WHEN** a vocabulary item is accepted for use
- **THEN** the backend stores its term, normalized term, language, Vietnamese meaning, part of speech, IPA, Vietnamese-friendly pronunciation, example, example translation, difficulty, topics, generation source, and timestamps

#### Scenario: Duplicate word is detected
- **WHEN** a vocabulary item has the same normalized term and language as an existing word
- **THEN** the backend prevents duplicate vocabulary storage

### Requirement: Backend accepts idempotent study event sync
The backend SHALL provide an API endpoint that accepts study events from mobile clients and treats `client_event_id` as an idempotency key.

#### Scenario: New study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id`
- **THEN** the backend stores the event and returns it as accepted

#### Scenario: Duplicate study event is retried
- **WHEN** the mobile app resends a study event with an already accepted `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result

### Requirement: Backend supports recent-word bootstrap
The backend SHALL provide an API endpoint that returns recent vocabulary items for bootstrapping or restoring a local mobile cache.

#### Scenario: Mobile requests recent words
- **WHEN** the mobile app requests recent words with a limit of 1000
- **THEN** the backend returns no more than 1000 recent vocabulary items

### Requirement: Backend data model supports future authentication
The backend SHALL support unauthenticated device-based usage while preserving a path to future user-based personalization.

#### Scenario: Study event is received before authentication exists
- **WHEN** the backend receives a study event without a user identity
- **THEN** the backend associates the event with the provided device identifier

#### Scenario: User identity is introduced later
- **WHEN** future authenticated requests include a user identifier
- **THEN** the backend data model can associate word state and study events with that user identifier without replacing existing device-based records
