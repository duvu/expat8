## MODIFIED Requirements

### Requirement: Card requests use local storage while backend refill is separate
The mobile app SHALL continue serving visible learning cards from local storage first, SHALL synchronize study events and content-pack/version updates in background workers, and SHALL treat backend as source of truth for assignment/proficiency reconciliation.

#### Scenario: Local card path remains non-blocking
- **WHEN** visible new/review card selection is requested and local eligible data exists
- **THEN** the app serves card locally without waiting on network sync or refill completion

#### Scenario: Background sync updates local inventory
- **WHEN** background worker syncs content-pack/version deltas or learning-card refill batches successfully
- **THEN** the app merges returned records into local store and updates local sync watermark/state

#### Scenario: Sync failure does not block session
- **WHEN** background sync fails due to timeout/network/backend rejection
- **THEN** the app keeps pending outbox items, records diagnostic logs, and allows ongoing local learning session
