## ADDED Requirements

### Requirement: Mobile loads an initial batch of words before showing the learning screen
The mobile app SHALL fetch a batch of 10 words from the backend and persist them locally before the learning screen is rendered for the first time in a session.

#### Scenario: First launch with empty local cache
- **WHEN** the app starts and the local word store contains fewer than 10 unlearned words
- **THEN** the app fetches a batch of 10 words from `POST /v1/learning/cards` and saves them locally before displaying the learning screen

#### Scenario: First launch with sufficient local cache
- **WHEN** the app starts and the local word store already contains 10 or more unlearned words
- **THEN** the app skips the initial fetch and displays the learning screen immediately

### Requirement: Mobile proactively prefetches words when the local queue runs low
The mobile app SHALL trigger a background fetch of 10 new words when the count of unlearned local words drops to 3 or fewer.

#### Scenario: Low-watermark reached during session
- **WHEN** the learner advances through cards and the local unlearned word count drops to 3
- **THEN** the app fires a background fetch of 10 words from the backend without interrupting the current card

#### Scenario: Prefetch already in flight
- **WHEN** a background prefetch is already in progress and the low-watermark is reached again
- **THEN** the app does not start a second concurrent prefetch

#### Scenario: Background fetch completes
- **WHEN** the background fetch returns words
- **THEN** the app persists the new words locally and the learning session continues uninterrupted

### Requirement: Mobile enforces a maximum of 1000 local words on every batch insert
The mobile app SHALL prune the oldest local words before inserting a new batch when the local word count is at or above 990.

#### Scenario: Local store is at cap
- **WHEN** the local word store contains 990 or more words and a new batch of 10 is about to be inserted
- **THEN** the app prunes the 10 oldest words that have no pending sync events before inserting the new 10

#### Scenario: Local store is below cap
- **WHEN** the local word store contains fewer than 990 words and a new batch of 10 is about to be inserted
- **THEN** the app inserts the batch without pruning
