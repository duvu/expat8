## MODIFIED Requirements

### Requirement: Backend initializes required schema
The backend deployment SHALL provide the database schema required by the service, including scale-aware proficiency persistence.

#### Scenario: Fresh PostgreSQL database is started through Compose
- **WHEN** the Compose stack starts PostgreSQL with an empty data volume
- **THEN** the database creates the tables and indexes required for words, study events, user word states, and scale-native proficiency metadata

## ADDED Requirements

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
