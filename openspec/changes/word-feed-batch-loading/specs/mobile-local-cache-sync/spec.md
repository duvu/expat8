## MODIFIED Requirements

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
