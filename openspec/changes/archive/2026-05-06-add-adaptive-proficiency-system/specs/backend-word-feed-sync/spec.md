## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns new vocabulary items for the mobile app, filtering by the user's current proficiency level.

#### Scenario: Mobile requests a new word with proficiency level
- **WHEN** the mobile app calls the new-word feed endpoint with source language, target language, mode, limit, and proficiency_level parameters
- **THEN** the backend returns vocabulary items matching the request parameters AND filtered to the specified proficiency level

#### Scenario: Existing suitable words are available at user proficiency level
- **WHEN** the backend has suitable stored words available at the user's proficiency level for a new-word request
- **THEN** the backend can return stored words matching that level without calling AI generation

#### Scenario: No words at exact proficiency level
- **WHEN** the backend has no suitable words at the user's exact proficiency level
- **THEN** the backend falls back to adjacent difficulty levels (A1→A2, B1→B2, etc.) in a defined order

### Requirement: Backend stores vocabulary records with CEFR difficulty level
The backend SHALL persist generated or accepted vocabulary items with CEFR difficulty levels (A1–C2) and other fields required by the mobile learning card.

#### Scenario: Word is persisted with CEFR level
- **WHEN** a vocabulary item is accepted for use
- **THEN** the backend stores its term, normalized term, language, Vietnamese meaning, part of speech, IPA, Vietnamese-friendly pronunciation, example, example translation, difficulty_level (A1–C2), topics, generation source, and timestamps

#### Scenario: Difficulty level must be valid CEFR
- **WHEN** a vocabulary item is ingested without a valid CEFR difficulty level (A1–C2)
- **THEN** the backend rejects the item or auto-maps legacy values (beginner→A1, intermediate→B1, advanced→C1)

#### Scenario: Duplicate word is detected
- **WHEN** a vocabulary item has the same normalized term and language as an existing word
- **THEN** the backend prevents duplicate vocabulary storage

### Requirement: Backend accepts idempotent study event sync with rating and proficiency response
The backend SHALL provide an API endpoint that accepts study events from mobile clients, includes difficulty ratings, tracks proficiency changes, and returns proficiency details in the response.

#### Scenario: New study event with rating is synced and triggers proficiency response
- **WHEN** the mobile app sends a study event with a new `client_event_id` and a difficulty rating (easy, too_easy, hard, too_hard)
- **THEN** the backend stores the event, evaluates if proficiency level should change, and returns proficiency details including current level, whether level changed, previous level, and triggering condition

#### Scenario: Duplicate study event with rating is retried
- **WHEN** the mobile app resends a study event with an already accepted `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result with current proficiency state

### Requirement: Backend supports recent-word bootstrap
The backend SHALL provide an API endpoint that returns recent vocabulary items for bootstrapping or restoring a local mobile cache.

#### Scenario: Mobile requests recent words
- **WHEN** the mobile app requests recent words with a limit of 1000
- **THEN** the backend returns no more than 1000 recent vocabulary items

### Requirement: Backend data model supports future authentication
The backend SHALL support unauthenticated device-based usage while preserving a path to future user-based personalization.

#### Scenario: Study event is received before authentication exists
- **WHEN** the backend receives a study event without a user identity
- **THEN** the backend associates the event with the provided device identifier and updates the device's proficiency level accordingly

#### Scenario: User identity is introduced later
- **WHEN** future authenticated requests include a user identifier
- **THEN** the backend data model can associate word state, study events, and proficiency with that user identifier without replacing existing device-based records
