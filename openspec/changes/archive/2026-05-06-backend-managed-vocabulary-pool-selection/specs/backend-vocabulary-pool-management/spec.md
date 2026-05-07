## ADDED Requirements

### Requirement: Backend maintains a minimum vocabulary pool
The backend SHALL maintain a prepared vocabulary pool of at least 1000 usable words per target language through asynchronous generation.

#### Scenario: Pool is below target
- **WHEN** the usable stored vocabulary count for a target language is below the configured minimum
- **THEN** the backend schedules AI generation without waiting for a mobile word request

#### Scenario: Pool reaches target
- **WHEN** the usable stored vocabulary count for a target language reaches the configured minimum
- **THEN** the backend stops minute-cadence fill generation for that language

### Requirement: Backend fills low inventory on a minute cadence
The backend SHALL inspect low vocabulary inventory on a configured minute cadence while the pool is below target.

#### Scenario: Fill interval elapses under target
- **WHEN** the fill interval elapses and a language has fewer than 1000 usable words
- **THEN** the backend attempts to generate and persist additional validated vocabulary for that language

#### Scenario: Generation fails during fill
- **WHEN** an AI generation attempt fails while the pool is under target
- **THEN** the backend records the failure and retries on a later scheduler tick without breaking mobile word requests

### Requirement: Backend adds daily top-up words after pool target
The backend SHALL generate a configured daily top-up after the vocabulary pool for a language is at or above the configured minimum.

#### Scenario: Daily top-up is due
- **WHEN** the pool has at least 1000 usable words and the daily generation window has not run for that language
- **THEN** the backend attempts to generate 10 new words for that language

#### Scenario: Daily top-up already ran
- **WHEN** the daily top-up has already completed for the language on the current day
- **THEN** the backend does not run another daily top-up for that language

### Requirement: Vocabulary generation is single-owner per language
The backend MUST prevent concurrent scheduler workers from generating duplicate vocabulary batches for the same language.

#### Scenario: Another worker owns generation
- **WHEN** a backend instance attempts to generate vocabulary for a language while another active worker holds the generation lock
- **THEN** the backend skips that generation attempt for the current tick

#### Scenario: Generation lock expires
- **WHEN** a generation lock is stale or expired
- **THEN** another backend worker can acquire the lock and continue generation

### Requirement: Generation attempts are observable
The backend SHALL record generation attempts with enough metadata to diagnose scheduler behavior and AI quality.

#### Scenario: Generation succeeds
- **WHEN** a scheduler run accepts generated words
- **THEN** the backend records the mode, language, requested count, accepted count, rejected count, start time, and finish time

#### Scenario: Generation fails
- **WHEN** a scheduler run fails before accepting words
- **THEN** the backend records the failure reason without exposing secrets
