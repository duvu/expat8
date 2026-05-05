## ADDED Requirements

### Requirement: Mobile stores learning data locally
The mobile app SHALL store vocabulary items, local word state, study events, sync queue entries, and app settings in local persistent storage.

#### Scenario: Vocabulary is saved locally
- **WHEN** the app receives or displays a vocabulary item
- **THEN** the app persists the item and its learning metadata locally

#### Scenario: Study event is saved before sync
- **WHEN** the user submits a study rating
- **THEN** the app writes the study event locally before attempting backend sync

### Requirement: Mobile retains at most one thousand local words
The mobile app MUST retain no more than 1000 vocabulary words in local storage.

#### Scenario: Local word count exceeds limit
- **WHEN** the local vocabulary store contains more than 1000 words
- **THEN** the app retains the 1000 most recent words and removes older local word records

#### Scenario: Removed word has pending sync data
- **WHEN** an older local word is eligible for removal and has unsynced study data
- **THEN** the app preserves the pending sync payload before removing the local word record

### Requirement: New-word requests fall back to local storage
The mobile app SHALL use local fallback when a backend new-word request fails, times out after 5 seconds, or the device is offline, and SHALL emit diagnostic logs for request attempts, fallback decisions, and fallback outcomes.

#### Scenario: Backend returns within timeout
- **WHEN** the app requests a new word and the backend returns a valid response within 5 seconds
- **THEN** the app saves the returned word locally, displays it, and records a success log event for the remote fetch path

#### Scenario: Backend request times out
- **WHEN** the app requests a new word and the backend does not return within 5 seconds
- **THEN** the app queries local eligible new words, displays one if available, and records timeout and fallback-attempt log events

#### Scenario: No local new word is available
- **WHEN** backend fallback is required and no eligible local new word exists
- **THEN** the app displays an eligible review word if one is available and records a fallback-result log event indicating source selection

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
