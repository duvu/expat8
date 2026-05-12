## Purpose
Define how the mobile app stores vocabulary, study events, sync queue entries, and settings in local ObjectBox persistent storage.
## Requirements
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
The mobile app MUST retain no more than 1000 vocabulary words in local storage. The cap MUST be enforced synchronously on every batch insertion, not only on periodic background runs.

#### Scenario: Batch insert when local store is at cap
- **WHEN** the local vocabulary store contains 990 or more words and a new batch of 10 is inserted
- **THEN** the app prunes the 10 oldest words with no pending sync data before inserting the new batch, keeping the total at or below 1000

#### Scenario: Batch insert when local store is below cap
- **WHEN** the local vocabulary store contains fewer than 990 words and a new batch of 10 is inserted
- **THEN** the app inserts the batch without pruning

#### Scenario: Removed word has pending sync data
- **WHEN** an older local word is eligible for removal and has unsynced study data
- **THEN** the app skips that word during pruning and removes the next oldest eligible word instead

### Requirement: New-word requests fall back to local storage
The mobile app SHALL use local fallback when the unified backend learning-card request fails, times out after 5 seconds, or the device is offline, and SHALL emit diagnostic logs for request attempts, fallback decisions, and fallback outcomes.

#### Scenario: Backend returns within timeout
- **WHEN** the app requests new learning cards and the backend returns a valid `/v1/learning/cards` response within 5 seconds
- **THEN** the app saves the returned words locally, displays an eligible local card, and records a success log event for the remote fetch path

#### Scenario: Backend request times out
- **WHEN** the app requests new learning cards and the backend does not return within 5 seconds
- **THEN** the app queries local eligible new words, displays one if available, and records timeout and fallback-attempt log events

#### Scenario: No local new word is available
- **WHEN** backend fallback is required and no eligible local new word exists
- **THEN** the app displays an eligible review word if one is available and records a fallback-result log event indicating source selection

#### Scenario: Legacy per-word request is not used
- **WHEN** the app needs more new words
- **THEN** the app does not call `/v1/words/next` and does not send `exclude_server_word_id` values

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

### Requirement: Mobile uses unified backend card refill
The mobile app SHALL refill local new-word cache by requesting 10 backend-selected new words from `/v1/learning/cards`.

#### Scenario: Local new-word cache is low
- **WHEN** the local cache needs more new words
- **THEN** the app requests `/v1/learning/cards` with `device_id`, target language, and limit 10

#### Scenario: Backend returns a partial batch
- **WHEN** the backend returns fewer than 10 new words
- **THEN** the app persists the returned words and continues using local fallback behavior for any remaining shortage

### Requirement: Mobile maintains anonymous learner identifier
The mobile app SHALL maintain a stable anonymous learner identifier in the form `anonymous_<uuid-v4>` when no user session exists.

#### Scenario: Anonymous identifier is missing
- **WHEN** the app starts and no local anonymous identifier exists
- **THEN** the app generates and stores a new `anonymous_<uuid-v4>` identifier

#### Scenario: Learning request is anonymous
- **WHEN** the app requests backend learning cards without a signed-in user session
- **THEN** the app sends the stable anonymous identifier as `device_id`

#### Scenario: User signs in
- **WHEN** the app requests backend learning cards with a signed-in user session
- **THEN** the app sends bearer authorization and still includes the stable `device_id` for device and cache context

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

