## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns new vocabulary items for the mobile app and SHALL apply proficiency filtering within the active language scale.

#### Scenario: Mobile requests a new word
- **WHEN** the mobile app calls the new-word feed endpoint with source language, target language, mode, and limit
- **THEN** the backend returns vocabulary items matching request parameters and filtered by the learner's proficiency scale and level for that target language

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a new-word request at the learner's resolved scale level
- **THEN** the backend can return stored words without calling AI generation

### Requirement: Backend accepts idempotent study event sync
The backend SHALL provide an API endpoint that accepts study events from mobile clients, treats `client_event_id` as an idempotency key, and returns scale-native proficiency state.

#### Scenario: New study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id`
- **THEN** the backend stores the event, updates proficiency in the active language scale, and returns accepted status with `proficiency.scale`, `proficiency.level`, and `proficiency.level_index`

#### Scenario: Duplicate study event is retried
- **WHEN** the mobile app resends a study event with an already accepted `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result with the same scale-native proficiency contract

## ADDED Requirements

### Requirement: Backend provides scale-native proficiency lookup
The backend SHALL return proficiency using language-native scale semantics when clients request proficiency state.

#### Scenario: Proficiency lookup for English
- **WHEN** the client requests proficiency for English
- **THEN** the backend returns proficiency with `scale=cefr` and a CEFR level value

#### Scenario: Proficiency lookup for Chinese
- **WHEN** the client requests proficiency for Chinese
- **THEN** the backend returns proficiency with `scale=hsk` and an HSK level value
