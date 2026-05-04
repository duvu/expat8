## ADDED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where a downward swipe requests the next vocabulary card.

#### Scenario: User swipes down for next card
- **WHEN** the user performs a downward swipe on the learning screen
- **THEN** the app selects and displays the next vocabulary card

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
The mobile app SHALL target a ratio of 3 new-word cards and 7 review-word cards across each 10-card learning window.

#### Scenario: Both new and review pools are available
- **WHEN** the user studies through a 10-card learning window with available new and review words
- **THEN** the app targets 3 new-word cards and 7 review-word cards in that window

#### Scenario: Target card type is unavailable
- **WHEN** the selected target card type has no available card
- **THEN** the app falls back to the other available card type without blocking the session

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
