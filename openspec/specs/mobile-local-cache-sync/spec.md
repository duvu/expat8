## ADDED Requirements

### Requirement: Mobile stores learning data locally
The mobile app SHALL store vocabulary items, local word state, study events, sync queue entries, and app settings in local persistent storage implemented with ObjectBox only.

#### Scenario: Vocabulary is saved locally
- **WHEN** the app receives or displays a vocabulary item
- **THEN** the app persists the item and its learning metadata locally via ObjectBox entities

#### Scenario: Study event is saved before sync
- **WHEN** the user submits a study rating
- **THEN** the app writes the study event locally via ObjectBox before attempting backend sync

### Requirement: SQLite backward compatibility is not supported
The mobile app MUST NOT read, migrate, or preserve legacy SQLite local data once ObjectBox storage is enabled for this change.

#### Scenario: Existing install has SQLite database file
- **WHEN** a user upgrades to a build containing ObjectBox-only storage
- **THEN** the app initializes ObjectBox local storage as the source of truth and ignores legacy SQLite data

#### Scenario: Startup initializes local persistence
- **WHEN** local persistence is initialized
- **THEN** the app does not execute SQLite schema creation or SQL migration logic

### Requirement: Mobile retains at most one thousand local words
The mobile app MUST retain no more than 1000 vocabulary words in local storage and MUST execute pruning in local database paths while preserving unsynced study payloads.

#### Scenario: Local word count exceeds limit
- **WHEN** local vocabulary exceeds 1000 records after insertion
- **THEN** the app retains the 1000 most recent eligible words and removes older local records

#### Scenario: Removed word has pending sync data
- **WHEN** an older local word is eligible for removal and has unsynced study data
- **THEN** the app preserves pending sync payload before removing that local word record

### Requirement: New-word requests fall back to local storage
The mobile app SHALL keep local-first study continuity and SHALL execute a daily cache refill check where unlearned-word count below 100 triggers fetching and storing 100 new words from backend.

#### Scenario: Daily check threshold reached
- **WHEN** the daily refresh worker runs and local unlearned-word count is below 100
- **THEN** the app requests 100 words from backend, stores returned words in local database, and records refill telemetry

#### Scenario: Daily check threshold not reached
- **WHEN** the daily refresh worker runs and local unlearned-word count is 100 or higher
- **THEN** the app skips backend refill and records a no-op refresh event

#### Scenario: Backend refill fails during daily check
- **WHEN** daily refill is required and backend request fails or times out
- **THEN** the app preserves existing local pool, records failure telemetry, and retries at next scheduled daily run without blocking learning session

#### Scenario: Refill check runs after new-word state transition
- **WHEN** a new-word card is shown and `markWordAsLearning` completes
- **THEN** the app runs the unstudied threshold check in the completion callback, ensuring the count has already been decremented before deciding whether to fetch

### Requirement: Sync queue retries failed uploads
The mobile app SHALL sync pending study events to the backend in the background and retry failed sync attempts, and SHALL log sync batch execution, retry scheduling, and terminal failure conditions.

#### Scenario: Sync succeeds
- **WHEN** a pending study event is accepted by the backend
- **THEN** the app marks that local event as synced and records a sync-success log event with batch metadata

#### Scenario: Sync fails
- **WHEN** a pending study event upload fails
- **THEN** the app keeps the event in the sync queue, schedules a retry, and records a sync-failure log event with sanitized error context

#### Scenario: User continues while sync is pending
- **WHEN** sync is pending or failing
- **THEN** the app allows the user to continue studying and records background-sync status transitions without blocking the session
