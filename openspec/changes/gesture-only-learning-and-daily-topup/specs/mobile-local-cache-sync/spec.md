## MODIFIED Requirements

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
