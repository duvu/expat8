## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Backend initializes required schema
The backend deployment SHALL provide the database schema required by the service, including persistence for words, study events, user word states, user cache inventory, user sessions, and explicit proficiency ownership.

#### Scenario: Fresh PostgreSQL database is started through Compose
- **WHEN** the Compose stack starts PostgreSQL with an empty data volume
- **THEN** the database creates the tables and indexes required for words, study events, user word states, cache inventory, sessions, and user/device proficiency records
