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
The mobile app MUST retain no more than 1000 vocabulary words in local storage.

#### Scenario: Local word count exceeds limit
- **WHEN** the local vocabulary store contains more than 1000 words
- **THEN** the app retains the 1000 most recent words and removes older local word records

#### Scenario: Removed word has pending sync data
- **WHEN** an older local word is eligible for removal and has unsynced study data
- **THEN** the app preserves the pending sync payload before removing the local word record

### Requirement: Card requests use local storage while backend refill is separate
The mobile app SHALL serve visible new/review card requests from ObjectBox local storage and SHALL use backend `/v1/learning/cards` only for inventory refill/top-up paths.

#### Scenario: Local new word is available
- **WHEN** the app requests a new word and local storage contains at least one eligible unstudied new word
- **THEN** the app serves the word from local storage without making a backend request in the visible card path

#### Scenario: Local new word is unavailable
- **WHEN** the app requests a new word and local storage has no eligible unstudied new word
- **THEN** the app may display an eligible review word if one is available and records a local-empty diagnostic log

#### Scenario: Backend refill succeeds
- **WHEN** inventory refill or top-up requests `/v1/learning/cards` and the backend returns a valid batch
- **THEN** the app saves the returned words locally through the capped ObjectBox write path

#### Scenario: Backend refill fails
- **WHEN** inventory refill or top-up fails due to timeout, network error, or backend rejection
- **THEN** the app logs the failure and continues serving any available local cards without blocking the visible session

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
