## MODIFIED Requirements

### Requirement: Backend initializes required schema
The backend deployment SHALL provide the database schema required by the service, including scale-aware proficiency persistence and performance indexes.

#### Scenario: Fresh PostgreSQL database is started through Compose
- **WHEN** the Compose stack starts PostgreSQL with an empty data volume
- **THEN** the database creates the tables and indexes required for words, study events, user word states, and scale-native proficiency metadata

#### Scenario: Index exists on user_word_states.word_id
- **WHEN** the database schema is initialized or migrated
- **THEN** an index exists on `user_word_states(word_id)` to support efficient JOIN lookups

## ADDED Requirements

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
