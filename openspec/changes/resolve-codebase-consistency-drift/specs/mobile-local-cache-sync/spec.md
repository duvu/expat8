## MODIFIED Requirements

### Requirement: Mobile retains at most one thousand local words
The mobile app MUST retain no more than 1000 vocabulary words in local storage, and the local persistence layer SHALL enforce this cap for every batch insert or refill path.

#### Scenario: Local word count exceeds limit
- **WHEN** the local vocabulary store contains more than 1000 words
- **THEN** the app retains the 1000 most recent words and removes older local word records

#### Scenario: Batch insert would exceed limit
- **WHEN** a batch insert or backend refill would increase local vocabulary storage above 1000 words
- **THEN** the local database completes the write with no more than 1000 retained vocabulary words

#### Scenario: Removed word has pending sync data
- **WHEN** an older local word is eligible for removal and has unsynced study data
- **THEN** the app preserves the pending sync payload before removing the local word record

#### Scenario: Multiple callers add words
- **WHEN** startup prefetch, backend-managed refill, daily refresh, or proactive refresh adds local words
- **THEN** each path uses the same local database retention boundary rather than relying on caller-specific prune logic
