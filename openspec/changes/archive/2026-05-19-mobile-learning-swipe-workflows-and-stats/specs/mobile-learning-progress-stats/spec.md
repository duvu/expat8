## ADDED Requirements

### Requirement: Mobile provides a learning progress stats page
The mobile app SHALL provide a progress stats page reachable from learning flows and SHALL summarize counts of learned, remembered, and difficult items across vocabulary and workplace sentence learning.

#### Scenario: Learner opens the progress stats page
- **WHEN** the learner requests progress stats from any learning screen
- **THEN** the app shows totals for learned, remembered, and difficult items aggregated from local learning state

### Requirement: Progress stats reflect local state immediately
The mobile app SHALL derive displayed counts from local database state and SHALL update counts after swipe actions without waiting for backend sync.

#### Scenario: Stats update after a swipe action
- **WHEN** the learner marks an item learned, remembered, or difficult
- **THEN** the progress stats page reflects the updated totals from local storage
