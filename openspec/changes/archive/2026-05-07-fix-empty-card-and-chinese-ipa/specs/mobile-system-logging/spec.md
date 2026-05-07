## ADDED Requirements

### Requirement: Mobile logs card-selection decisions and empty-card causes
The mobile app SHALL record structured diagnostic logs for learning-card selection decisions, fallback paths, and final empty-card causes.

#### Scenario: Card selection starts
- **WHEN** the session controller begins selecting the next card
- **THEN** the app records the requested selection mode, active learning language, preferred card kind, and rolling mix state

#### Scenario: Selector falls back from new to review
- **WHEN** the preferred card kind is new-word and no new word is available
- **THEN** the app records a fallback event before attempting learned or reviewable card selection

#### Scenario: Selector falls back from review to new
- **WHEN** the preferred card kind is review and no learned or reviewable card is available
- **THEN** the app records a fallback event before attempting new-word card selection

#### Scenario: Selector cannot find any card
- **WHEN** no new, learned, due-review, difficult-relearn, or recent-review card is available
- **THEN** the app records an empty-card event that includes the attempted sources and active learning language
