## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where a downward swipe requests the next vocabulary card, and SHALL log session navigation actions and card-source decisions for troubleshooting.

#### Scenario: User swipes down for next card
- **WHEN** the user performs a downward swipe on the learning screen
- **THEN** the app selects and displays the next vocabulary card and records a session-navigation log event

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app loads the most recent local learning state before starting the session and records initialization log events for restored state

### Requirement: Review scheduling updates after ratings
The mobile app SHALL allow the user to submit a memory rating and update the word review schedule locally, and SHALL log rating submissions and computed scheduling decisions.

#### Scenario: User rates a card
- **WHEN** the user submits a rating for the current card
- **THEN** the app records the rating, computes the next local review time for that word, and writes a scheduling log event

#### Scenario: User marks a card as forgotten
- **WHEN** the user rates a card as not remembered
- **THEN** the app schedules that word for near-term review and logs the resulting schedule change

#### Scenario: User marks a card as easy
- **WHEN** the user rates a card as too easy
- **THEN** the app schedules that word farther in the future than a normally remembered word and logs the resulting schedule change
