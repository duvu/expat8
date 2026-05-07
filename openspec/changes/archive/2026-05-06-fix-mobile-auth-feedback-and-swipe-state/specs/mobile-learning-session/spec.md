## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where horizontal swipe direction and visible new/review actions request the next vocabulary card, and failed requests SHALL produce visible feedback instead of silently keeping stale state.

#### Scenario: User requests a new word
- **WHEN** the user performs the configured new-word horizontal swipe or taps the visible new-word action on the learning screen
- **THEN** the app requests and displays a new vocabulary card when one is available

#### Scenario: User requests recent review
- **WHEN** the user performs the configured recent-review horizontal swipe or taps the visible review action on the learning screen
- **THEN** the app requests and displays a recently learned review card when one is available

#### Scenario: Gesture is too weak to classify
- **WHEN** the user performs a horizontal drag that does not meet the configured gesture threshold
- **THEN** the app either leaves the current card unchanged with a visible hint for valid actions or provides visible new/review buttons that remain usable

#### Scenario: Requested card is unavailable
- **WHEN** a new/review request cannot load a backend word or local fallback word
- **THEN** the app shows a visible no-card or error state instead of silently rendering the previous card as if nothing happened

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app loads the most recent local learning state before starting the session

### Requirement: Vocabulary card displays required learning content
The mobile app SHALL display all required vocabulary fields on each card when the data is available.

#### Scenario: Complete vocabulary card is shown
- **WHEN** a vocabulary card is displayed
- **THEN** the card includes the term, Vietnamese meaning, Vietnamese-friendly pronunciation, IPA, example sentence, and Vietnamese example translation

#### Scenario: Optional part of speech is available
- **WHEN** a vocabulary item includes part of speech
- **THEN** the card displays the part of speech with the vocabulary term

### Requirement: Session targets three new words and seven review words
The mobile app SHALL target a ratio of 3 new-word cards and 7 review-word cards across each 10-card learning window when automatic card selection is used.

#### Scenario: Both new and review pools are available
- **WHEN** the user studies through a 10-card learning window with available new and review words using automatic selection
- **THEN** the app targets 3 new-word cards and 7 review-word cards in that window

#### Scenario: Target card type is unavailable
- **WHEN** the selected target card type has no available card
- **THEN** the app falls back to the other available card type without blocking the session and displays feedback if neither type is available

### Requirement: Review scheduling updates after ratings
The mobile app SHALL allow the user to submit a memory rating and update the word review schedule locally.

#### Scenario: User rates a card
- **WHEN** the user submits a rating for the current card
- **THEN** the app records the rating and computes the next local review time for that word

#### Scenario: User marks a card as forgotten
- **WHEN** the user rates a card as not remembered
- **THEN** the app schedules that word for near-term review

#### Scenario: User marks a card as easy
- **WHEN** the user rates a card as too easy
- **THEN** the app schedules that word farther in the future than a normally remembered word
