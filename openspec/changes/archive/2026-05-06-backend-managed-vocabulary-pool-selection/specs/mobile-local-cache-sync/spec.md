## ADDED Requirements

### Requirement: Mobile reports local cache inventory to backend
The mobile app SHALL report active local `server_word_id` inventory to the backend so backend card selection can avoid cached duplicates.

#### Scenario: App starts with local words
- **WHEN** the app starts and local words exist
- **THEN** the app syncs the current active local cache inventory to the backend

#### Scenario: Local cache changes
- **WHEN** the app adds, removes, or prunes local words
- **THEN** the app schedules or performs cache inventory sync with the backend

### Requirement: Mobile removes easy-rated words after preserving study data
The mobile app SHALL remove an easy-rated word from local vocabulary storage only after preserving the local study event.

#### Scenario: User marks a word easy
- **WHEN** the user rates the current word as `easy`
- **THEN** the app writes the study event locally and removes the word from `local_words`

#### Scenario: Easy event is not yet synced
- **WHEN** the easy-rated word is removed locally before backend sync succeeds
- **THEN** the app preserves the pending sync payload with the server word ID and local word ID

### Requirement: Mobile refills local cache from backend-selected batches
The mobile app SHALL request backend-selected card batches when local active cards fall below the refill threshold.

#### Scenario: Local active cache is low
- **WHEN** the number of local cards eligible for display falls below the configured threshold
- **THEN** the app requests a backend-selected learning-card batch and stores returned cards locally

#### Scenario: Backend refill fails
- **WHEN** the backend-selected batch request fails
- **THEN** the app keeps existing local data and allows queued study-event sync to continue

## MODIFIED Requirements

### Requirement: Mobile retains at most one thousand local words
The mobile app MUST retain no more than 1000 vocabulary words in local storage while preserving pending study-event sync payloads and reporting inventory changes.

#### Scenario: Local word count exceeds limit
- **WHEN** the local vocabulary store contains more than 1000 words
- **THEN** the app retains the 1000 most recent active words, removes older local word records, and schedules cache inventory sync

#### Scenario: Removed word has pending sync data
- **WHEN** an older local word is eligible for removal and has unsynced study data
- **THEN** the app preserves the pending sync payload before removing the local word record
