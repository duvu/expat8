## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns new vocabulary items for the mobile app and can exclude words already learned by the signed-in user or anonymous device.

#### Scenario: Mobile requests a new word
- **WHEN** the mobile app calls the new-word feed endpoint with source language, target language, mode, limit, and optional user identity
- **THEN** the backend returns vocabulary items matching the request parameters

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a new-word request
- **THEN** the backend can return stored words without calling AI generation

#### Scenario: Signed-in learner has already learned a word
- **WHEN** the backend selects new vocabulary for a signed-in user
- **THEN** the backend excludes words already tracked as learned by that user when alternatives are available

### Requirement: Backend accepts idempotent study event sync
The backend SHALL provide an API endpoint that accepts study events from mobile clients, treats `client_event_id` as an idempotency key, and associates signed-in events with the user when identity is present.

#### Scenario: New anonymous study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id` and no user identity
- **THEN** the backend stores the event with the provided device identifier and returns it as accepted

#### Scenario: New signed-in study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id` and valid user identity
- **THEN** the backend stores the event with both user and device association and returns it as accepted

#### Scenario: Duplicate study event is retried
- **WHEN** the mobile app resends a study event with an already accepted `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result

### Requirement: Backend data model supports future authentication
The backend SHALL support both unauthenticated device-based usage and signed-in user-based personalization.

#### Scenario: Study event is received before sign-in
- **WHEN** the backend receives a study event without a user identity
- **THEN** the backend associates the event with the provided device identifier

#### Scenario: Study event is received after sign-in
- **WHEN** the backend receives a study event with valid user identity
- **THEN** the backend associates word state and study history with the user without replacing existing device-based records

#### Scenario: Signed-in user requests learned-word-aware feed
- **WHEN** a signed-in request asks for new vocabulary
- **THEN** the backend can use user-associated learned-word state to avoid repeating already learned words
