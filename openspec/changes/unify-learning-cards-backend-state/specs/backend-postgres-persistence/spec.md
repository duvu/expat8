## MODIFIED Requirements

### Requirement: Backend uses PostgreSQL for persistent storage
The backend SHALL persist vocabulary words, study events, user word states, and active cache/claim inventory in PostgreSQL when configured for deployment.

#### Scenario: Backend starts with database configuration
- **WHEN** the backend starts with a valid PostgreSQL connection string
- **THEN** the backend connects to PostgreSQL and uses it for read and write operations

#### Scenario: Backend restarts after data is written
- **WHEN** vocabulary words, study events, user word states, or active cache claims were stored before a backend restart
- **THEN** the backend can read the stored data after restart from PostgreSQL

### Requirement: Backend initializes required schema
The backend deployment SHALL provide the database schema required by the service.

#### Scenario: Fresh PostgreSQL database is started through Compose
- **WHEN** the Compose stack starts PostgreSQL with an empty data volume
- **THEN** the database creates the tables and indexes required for words, study events, user word states, and user cached word inventory

#### Scenario: Cache inventory indexes are created
- **WHEN** the database schema is initialized or migrated
- **THEN** the schema enforces idempotent active cache inventory rows per anonymous device word and per signed-in user word

## ADDED Requirements

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
