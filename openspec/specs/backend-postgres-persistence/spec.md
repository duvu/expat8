## ADDED Requirements

### Requirement: Backend uses PostgreSQL for persistent storage
The backend SHALL persist vocabulary words, study events, and user word states in PostgreSQL when configured for deployment.

#### Scenario: Backend starts with database configuration
- **WHEN** the backend starts with a valid PostgreSQL connection string
- **THEN** the backend connects to PostgreSQL and uses it for read and write operations

#### Scenario: Backend restarts after data is written
- **WHEN** vocabulary words or study events were stored before a backend restart
- **THEN** the backend can read the stored data after restart from PostgreSQL

### Requirement: Backend preserves vocabulary storage behavior
The backend SHALL preserve the existing vocabulary storage contract while using PostgreSQL.

#### Scenario: Word is persisted
- **WHEN** a vocabulary item is accepted for storage
- **THEN** the backend stores the term, normalized term, language, Vietnamese meaning, part of speech, IPA, Vietnamese-friendly pronunciation, example, example translation, difficulty, topics, generation source, and timestamps in PostgreSQL

#### Scenario: Duplicate word is detected
- **WHEN** a vocabulary item has the same normalized term and language as an existing PostgreSQL row
- **THEN** the backend returns the existing word instead of creating a duplicate row

### Requirement: Backend preserves idempotent study event sync
The backend SHALL treat `client_event_id` as an idempotency key when syncing study events into PostgreSQL.

#### Scenario: New study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id`
- **THEN** the backend stores the event in PostgreSQL and returns it as accepted

#### Scenario: Duplicate study event is retried
- **WHEN** the mobile app resends a study event with an already stored `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result

### Requirement: Backend initializes required schema
The backend deployment SHALL provide the database schema required by the service, including scale-aware proficiency persistence.

#### Scenario: Fresh PostgreSQL database is started through Compose
- **WHEN** the Compose stack starts PostgreSQL with an empty data volume
- **THEN** the database creates the tables and indexes required for words, study events, user word states, and scale-native proficiency metadata

### Requirement: Backend persists proficiency scale metadata per learner and language
The backend SHALL persist proficiency using language, scale, level, and deterministic level ordering metadata for each learner identity.

#### Scenario: New proficiency state is initialized
- **WHEN** a learner first requests proficiency for a language
- **THEN** the backend stores a proficiency record with language-specific `scale`, initial `level`, and `level_index`

#### Scenario: Proficiency state is updated from study events
- **WHEN** progression or regression is triggered by study events
- **THEN** the backend updates `scale`, `level`, and `level_index` atomically for that learner-language state

### Requirement: Backend queries proficiency by identity and language
The backend SHALL resolve persisted proficiency by user/device identity and target language without cross-language contamination.

#### Scenario: Same user studies two languages
- **WHEN** proficiency is queried for one language
- **THEN** the backend returns only the proficiency state belonging to that language

#### Scenario: Device-only and user-bound identities coexist
- **WHEN** anonymous and signed-in sessions both exist
- **THEN** the backend can query and return the correct language-scoped proficiency state for each identity mode
