## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where horizontal swipe direction selects whether the next card is a new word or a recently learned review word.

#### Scenario: User swipes right-to-left for a new word
- **WHEN** the user performs a right-to-left swipe on the learning screen
- **THEN** the app requests and displays a new vocabulary card if one is available

#### Scenario: User swipes left-to-right for recent review
- **WHEN** the user performs a left-to-right swipe on the learning screen
- **THEN** the app requests and displays a recently learned review card if one is available

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app loads the most recent local learning state before starting the session

## ADDED Requirements

### Requirement: Recent review prefers just-learned words
The mobile app SHALL provide a review path that prioritizes words the learner has recently studied.

#### Scenario: Recently learned words exist
- **WHEN** the learner swipes left-to-right and recently learned words are available
- **THEN** the app displays one of the recently learned words for review

#### Scenario: No recently learned words exist
- **WHEN** the learner swipes left-to-right and no recently learned word is available
- **THEN** the app falls back to an eligible scheduled review word if one is available
