# mobile-learning-history-view Specification

## Purpose
TBD - created by archiving change mobile-learning-swipe-workflows-and-stats. Update Purpose after archive.
## Requirements
### Requirement: Mobile provides an ordered history view for learned items
The mobile app SHALL provide a history view accessible from all learning screens and SHALL populate it from the local ordered history trail created by right-to-left learning swipes.

#### Scenario: Vocabulary screen opens history view
- **WHEN** the learner performs a left-to-right swipe on the vocabulary learning screen
- **THEN** the app opens the history view instead of advancing the vocabulary session

#### Scenario: Sentence screen opens history view
- **WHEN** the learner performs a left-to-right swipe on the workplace sentence learning screen
- **THEN** the app opens the history view instead of advancing the sentence session

### Requirement: History view preserves learned order
The mobile app SHALL list learned items in the same chronological order they were marked learned and SHALL show item context when available.

#### Scenario: History contains multiple learned items
- **WHEN** the local history trail contains multiple right-to-left learned items
- **THEN** the history view displays them in the same order they were recorded

#### Scenario: No learned history exists yet
- **WHEN** no item has been marked learned via a right-to-left swipe
- **THEN** the history view shows an empty state

