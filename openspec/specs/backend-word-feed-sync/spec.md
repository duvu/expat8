## ADDED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns vocabulary items for mobile learning flows, including batch retrieval for local top-up requests.

#### Scenario: Mobile requests top-up batch
- **WHEN** the mobile app requests learning cards with a top-up limit of 100
- **THEN** the backend returns up to 100 vocabulary items matching request parameters and availability constraints

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a learning-card request
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
The backend SHALL provide an API endpoint that accepts study events from mobile clients, treats `client_event_id` as an idempotency key, and returns scale-native proficiency state.

#### Scenario: New study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id`
- **THEN** the backend stores the event, updates proficiency in the active language scale, and returns accepted status with `proficiency.scale`, `proficiency.level`, and `proficiency.level_index`

#### Scenario: Duplicate study event is retried
- **WHEN** the mobile app resends a study event with an already accepted `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result with the same scale-native proficiency contract

### Requirement: Backend provides scale-native proficiency lookup
The backend SHALL return proficiency using language-native scale semantics when clients request proficiency state.

#### Scenario: Proficiency lookup for English
- **WHEN** the client requests proficiency for English
- **THEN** the backend returns proficiency with `scale=cefr` and a CEFR level value

#### Scenario: Proficiency lookup for Chinese
- **WHEN** the client requests proficiency for Chinese
- **THEN** the backend returns proficiency with `scale=hsk` and an HSK level value

### Requirement: Backend supports recent-word bootstrap
The backend SHALL support mobile local-cache bootstrap and refill behavior by returning bounded recent vocabulary datasets compatible with 1000-word local cache policy.

#### Scenario: Mobile requests recent words
- **WHEN** the mobile app requests recent words for cache bootstrap with limit up to 1000
- **THEN** the backend returns no more than 1000 recent vocabulary items

#### Scenario: Mobile requests incremental refill
- **WHEN** the mobile app requests incremental refill with limit 100
- **THEN** the backend returns a bounded set that can be merged locally without requiring server-side session state

### Requirement: Backend data model supports future authentication
The backend SHALL support unauthenticated device-based usage while preserving a path to future user-based personalization.

#### Scenario: Study event is received before authentication exists
- **WHEN** the backend receives a study event without a user identity
- **THEN** the backend associates the event with the provided device identifier

#### Scenario: User identity is introduced later
- **WHEN** future authenticated requests include a user identifier
- **THEN** the backend data model can associate word state and study events with that user identifier without replacing existing device-based records
