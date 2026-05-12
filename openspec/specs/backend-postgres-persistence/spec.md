## Purpose
Define how the backend persists vocabulary, study events, user word states, and proficiency data in PostgreSQL.
## Requirements
### Requirement: Backend uses PostgreSQL for persistent storage
The backend SHALL persist vocabulary words, study events, user word states, and active cache/claim inventory in PostgreSQL when configured for deployment.

#### Scenario: Backend starts with database configuration
- **WHEN** the backend starts with a valid PostgreSQL connection string
- **THEN** the backend connects to PostgreSQL and uses it for read and write operations

#### Scenario: Backend restarts after data is written
- **WHEN** vocabulary words, study events, user word states, or active cache claims were stored before a backend restart
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
The backend deployment SHALL provide the database schema required by the service.

#### Scenario: Fresh PostgreSQL database is started through Compose
- **WHEN** the Compose stack starts PostgreSQL with an empty data volume
- **THEN** the database creates the tables and indexes required for words, study events, user word states, and user cached word inventory

#### Scenario: Cache inventory indexes are created
- **WHEN** the database schema is initialized or migrated
- **THEN** the schema enforces idempotent active cache inventory rows per anonymous device word and per signed-in user word

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

### Requirement: Backend uses efficient SQL queries for learning card selection
The backend SHALL query learning cards using database-level filtering and limiting rather than loading the full word set into memory.

#### Scenario: Learning cards are requested for a small vocabulary pool
- **WHEN** the backend selects learning cards for a device
- **THEN** the backend uses SQL JOINs and WHERE clauses to filter and limit at the database layer

#### Scenario: Learning cards are requested when word table is large
- **WHEN** the vocabulary table contains a large number of entries
- **THEN** the backend returns results without loading all entries into application memory

### Requirement: Backend uses explicit Postgres connection pool configuration
The backend SHALL configure the Postgres connection pool with explicit `max`, `idleTimeoutMillis`, and `connectionTimeoutMillis` values rather than relying on driver defaults.

#### Scenario: Pool configuration is applied at startup
- **WHEN** the backend starts with a PostgreSQL connection string
- **THEN** the connection pool is created with the configured max connections, idle timeout, and connection timeout

#### Scenario: Pool configuration can be overridden via environment
- **WHEN** pool configuration values are set in runtime config
- **THEN** the pool uses those values instead of hardcoded defaults

### Requirement: Backend stores proficiency with explicit owner uniqueness
The PostgreSQL schema SHALL store anonymous proficiency by device and signed-in proficiency by user without encoding user ownership inside synthetic device identifiers.

#### Scenario: Anonymous proficiency is initialized
- **WHEN** an anonymous request initializes proficiency for a device and language
- **THEN** PostgreSQL stores one proficiency row unique to that device and language with `user_id` unset

#### Scenario: Signed-in proficiency is initialized
- **WHEN** a signed-in request initializes proficiency for a user and language
- **THEN** PostgreSQL stores one proficiency row unique to that user and language without using a `device_id` value derived from the user ID

#### Scenario: Existing duplicate user proficiency rows are migrated
- **WHEN** a migration finds multiple proficiency rows for the same user and language
- **THEN** the migration preserves a deterministic latest row before adding the user-language uniqueness constraint

### Requirement: Backend persists active card claims
The backend SHALL persist word IDs returned by `/v1/learning/cards` as active cache/claim inventory for the resolved learner context.

#### Scenario: Anonymous learner receives a batch
- **WHEN** the backend returns new cards for an anonymous `device_id`
- **THEN** the backend records the returned server word IDs under that anonymous device inventory before completing the response

#### Scenario: Signed-in learner receives a batch
- **WHEN** the backend returns new cards for a valid bearer session and `device_id`
- **THEN** the backend records the returned server word IDs under the signed-in user inventory while retaining device context

#### Scenario: Batch claim is retried
- **WHEN** the backend attempts to record a word ID already active for the same learner context
- **THEN** the backend treats the claim as idempotent and does not create duplicate inventory rows

### Requirement: Backend projects study events into latest learner word state
The backend SHALL maintain latest per-learner word state from accepted study events for efficient card selection.

#### Scenario: Study event is accepted
- **WHEN** the backend accepts a study event with a server word ID
- **THEN** the backend inserts or updates the latest learner word state for that word and owner context

#### Scenario: Completed word is selected as new
- **WHEN** a word has latest learner state of completed for the resolved learner context
- **THEN** backend new-card selection excludes that word from future new-card responses

