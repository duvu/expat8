## MODIFIED Requirements

### Requirement: Mobile retains at most one thousand local words
The mobile app MUST retain no more than 1000 vocabulary words in local storage and MUST execute pruning with smart priority (mastered words first, then overdue-far review words, then oldest) after every batch insert while preserving unsynced study payloads.

#### Scenario: Local word count exceeds limit — mastered words exist
- **WHEN** local vocabulary exceeds 1000 records after batch insertion and some words have `mastered` status
- **THEN** the app removes mastered words first (ordered by least-recently-seen), continuing until the count is at or below 1000 or no mastered words remain

#### Scenario: Local word count still exceeds limit — no mastered words remain
- **WHEN** local vocabulary still exceeds 1000 records after removing all mastered words
- **THEN** the app removes review words whose next review date is more than 30 days in the future (ordered by farthest next-review-date first), continuing until at or below 1000 or none remain

#### Scenario: Local word count still exceeds limit — fallback to oldest
- **WHEN** local vocabulary still exceeds 1000 records after the two smart prune passes
- **THEN** the app removes words ordered by creation date ascending (oldest first) until the count reaches 1000

#### Scenario: Removed word has pending sync data
- **WHEN** a word is a candidate for removal but has unsynced study data
- **THEN** the app skips that word and selects the next eligible candidate in the same priority order

#### Scenario: Local word count is within limit
- **WHEN** local vocabulary is at or below 1000 records after batch insertion
- **THEN** the app does not remove any words
