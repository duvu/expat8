## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where directional gestures drive session actions: right-to-left selects another card biased to 15% learned-word review, left-to-right routes to review flow with 15% new-word weighting, bottom-to-top marks remembered and reduces relearning frequency to 10%, and top-to-bottom marks difficult and adds the word to relearn group. The app SHALL log session navigation actions and card-source decisions for troubleshooting.

#### Scenario: User swipes right-to-left for another card
- **WHEN** the user performs a right-to-left swipe on the learning screen
- **THEN** the app selects and displays the next vocabulary card and records a session-navigation log event with learned-word review weighting at 15%

#### Scenario: User swipes left-to-right for review flow
- **WHEN** the user performs a left-to-right swipe on the learning screen
- **THEN** the app advances to the next card using review flow selection and records a session-navigation log event with new-word weighting at 15%

#### Scenario: User swipes bottom-to-top to mark remembered
- **WHEN** the user performs a bottom-to-top swipe on the learning screen
- **THEN** the app updates local word state as remembered, reduces relearning frequency to 10% for that word, and records scheduling and navigation log events

#### Scenario: User swipes top-to-bottom to mark difficult
- **WHEN** the user performs a top-to-bottom swipe on the learning screen
- **THEN** the app updates local word state as difficult, assigns the word to relearn group, and records scheduling and navigation log events

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app loads the most recent local learning state before starting the session and records initialization log events for restored state

### Requirement: Review scheduling updates after ratings
The mobile app SHALL derive remembered/difficult scheduling updates from gesture intents and update the word review schedule locally, and SHALL log gesture-derived scheduling decisions.

#### Scenario: User marks a card as difficult
- **WHEN** the user performs the top-to-bottom difficult gesture for the current card
- **THEN** the app schedules that word for near-term relearn review and logs the resulting schedule change

#### Scenario: User marks a card as remembered
- **WHEN** the user performs the bottom-to-top remembered gesture for the current card
- **THEN** the app schedules that word farther in the future with relearning frequency reduced to 10% and logs the resulting schedule change
