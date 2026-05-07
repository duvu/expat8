## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide API endpoints that return database-backed vocabulary items for the mobile app without invoking AI generation during the request.

#### Scenario: Mobile requests a new word
- **WHEN** the mobile app calls the compatible new-word feed endpoint with source language, target language, mode, and limit
- **THEN** the backend returns eligible stored vocabulary items matching the request parameters

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a new-word request
- **THEN** the backend returns stored words without calling AI generation

#### Scenario: Existing suitable words are unavailable
- **WHEN** the backend does not have suitable stored words available for a new-word request
- **THEN** the backend returns an empty or partial database-backed response without calling AI generation

### Requirement: Backend accepts idempotent study event sync
The backend SHALL provide API endpoints that accept study events from mobile clients, treat `client_event_id` as an idempotency key, and update latest learner word state for accepted events.

#### Scenario: New study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id`
- **THEN** the backend stores the event, updates latest learner word state, and returns it as accepted

#### Scenario: Duplicate study event is retried
- **WHEN** the mobile app resends a study event with an already accepted `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result

#### Scenario: Easy rating is accepted
- **WHEN** the backend accepts an `easy` study event for a word
- **THEN** the backend marks that word as completed or excluded from future new-card selection for the learner

## ADDED Requirements

### Requirement: Backend provides batch learning cards
The backend SHALL provide a batch-oriented learning-card endpoint for the mobile app.

#### Scenario: Mobile requests a card batch
- **WHEN** the mobile app requests a batch of learning cards with `device_id`, target language, and limit
- **THEN** the backend returns database-backed card items with card type metadata

#### Scenario: Signed-in mobile requests a card batch
- **WHEN** the mobile app requests a card batch with a valid bearer session
- **THEN** the backend applies signed-in user state while retaining device cache exclusions
