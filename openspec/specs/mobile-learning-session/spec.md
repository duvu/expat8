## ADDED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where horizontal swipes request new or review vocabulary cards, vertical swipes update the current card's local learning state, and session navigation stays scoped to the active learning language and proficiency scale.

#### Scenario: User swipes right-to-left for a new card
- **WHEN** the user performs a right-to-left swipe on the learning screen
- **THEN** the app requests a new-card-biased selection using the active language and current scale-native proficiency state

#### Scenario: User swipes left-to-right for review
- **WHEN** the user performs a left-to-right swipe on the learning screen
- **THEN** the app requests a review-biased selection using the active language and current scale-native proficiency state

#### Scenario: User swipes vertically on current card
- **WHEN** the user performs a vertical swipe on the current card
- **THEN** the app updates the current card's local learning state and advances to another locally selected card

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app restores session state including active language and associated proficiency scale metadata before continuing the session

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
The mobile app SHALL allow the user to submit a memory rating and SHALL update local proficiency state from backend scale-native responses.

#### Scenario: User rates a card
- **WHEN** the user submits a rating for the current card
- **THEN** the app records the rating and applies returned `proficiency.scale`, `proficiency.level`, and `proficiency.level_index` to session state

#### Scenario: Proficiency level changes
- **WHEN** the backend reports a level change after rating submission
- **THEN** the app updates the displayed level label according to the returned scale without assuming CEFR-only semantics

### Requirement: Mobile renders proficiency labels by language scale
The mobile app SHALL render proficiency labels using language-native scale conventions.

#### Scenario: English session label
- **WHEN** the active learning language is English
- **THEN** the app renders CEFR labels such as A1 through C2

#### Scenario: Chinese session label
- **WHEN** the active learning language is Chinese
- **THEN** the app renders HSK labels such as HSK1 through HSK6
