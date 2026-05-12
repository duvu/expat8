## Purpose
Define how the mobile learning session selects cards, handles gestures, updates local learning state, and renders language-native proficiency labels.
## Requirements
### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where a downward swipe requests the next vocabulary card, SHALL show the current active learning language on that screen, and SHALL keep session navigation scoped to the selected learning language and proficiency scale.

#### Scenario: User swipes down for next card
- **WHEN** the user performs a downward swipe on the learning screen
- **THEN** the app requests the next card using the active language and current scale-native proficiency state

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app restores session state including active language and associated proficiency scale metadata before continuing the session

#### Scenario: User changes the active learning language
- **WHEN** the user selects a different learning language from the learning screen
- **THEN** the app reloads proficiency and subsequent card requests in the newly selected language

#### Scenario: Active language changes while a card is visible
- **WHEN** the user switches to another learning language while a card from the previous language is displayed
- **THEN** the app replaces that language context with content for the newly selected language instead of continuing the old one

### Requirement: Vocabulary card displays required learning content
The mobile app SHALL display all required vocabulary fields on each card when the data is available and SHALL expose optional speaking practice content when an approved speaking prompt or fallback example is available.

#### Scenario: Complete vocabulary card is shown
- **WHEN** a vocabulary card is displayed
- **THEN** the card includes the term, Vietnamese meaning, Vietnamese-friendly pronunciation, IPA, example sentence, and Vietnamese example translation

#### Scenario: Optional part of speech is available
- **WHEN** a vocabulary item includes part of speech
- **THEN** the card displays the part of speech with the vocabulary term

#### Scenario: Optional speaking prompt is available
- **WHEN** a vocabulary card includes an approved speaking prompt
- **THEN** the card exposes a non-blocking speaking entry point with target text and Vietnamese hint for local speaking practice

### Requirement: Review scheduling updates after ratings
The mobile app SHALL derive remembered/difficult scheduling updates from gesture intents and update the word review schedule locally, and SHALL log gesture-derived scheduling decisions.

#### Scenario: User marks a card as difficult
- **WHEN** the user performs the top-to-bottom difficult gesture for the current card
- **THEN** the app schedules that word for near-term relearn review and logs the resulting schedule change

#### Scenario: User marks a card as remembered
- **WHEN** the user performs the bottom-to-top remembered gesture for the current card
- **THEN** the app schedules that word farther in the future with relearning frequency reduced to 10% and logs the resulting schedule change

### Requirement: Mobile renders proficiency labels by language scale
The mobile app SHALL render proficiency labels using language-native scale conventions.

#### Scenario: English session label
- **WHEN** the active learning language is English
- **THEN** the app renders CEFR labels such as A1 through C2

#### Scenario: Chinese session label
- **WHEN** the active learning language is Chinese
- **THEN** the app renders HSK labels such as HSK1 through HSK6

### Requirement: Session targets fifteen percent new cards and eighty-five percent review cards
The mobile app SHALL target 15% new-word cards and 85% review or learned-word cards across normal learning progression.

#### Scenario: Both new and review pools are available
- **WHEN** the user studies through a rolling 20-card learning window with available new and review words
- **THEN** the app targets 3 new-word cards and 17 review or learned-word cards in that window

#### Scenario: New-word pool is exhausted
- **WHEN** the selected target card type is new-word and no new word is available for the active language
- **THEN** the app falls back to a learned, due-review, difficult-relearn, or recent-review card before showing an empty-card message

#### Scenario: Review pool is exhausted
- **WHEN** the selected target card type is review and no learned or reviewable card is available for the active language
- **THEN** the app falls back to an available new-word card before showing an empty-card message

#### Scenario: All local card pools are exhausted
- **WHEN** no new, learned, due-review, difficult-relearn, or recent-review card is available for the active language
- **THEN** the app may show an empty-card message explaining that no learning card is available

### Requirement: Session uses backend-owned new-word batches
The mobile learning session SHALL consume backend-owned new-word batches without sending current card IDs or word exclusion lists.

#### Scenario: New-word batch is requested
- **WHEN** the learning session requests new remote supply
- **THEN** the request uses the unified learning-card endpoint with limit 10 and omits current word ID and exclude word IDs

#### Scenario: Remote batch fails
- **WHEN** the unified learning-card endpoint fails during a session
- **THEN** the session continues with eligible local cards when available and does not fall back to the removed legacy endpoint

### Requirement: Speaking entry points preserve swipe behavior
The mobile learning session SHALL keep speaking practice optional and SHALL NOT require speaking before the learner can continue normal card navigation.

#### Scenario: Learner skips speaking prompt
- **WHEN** a speaking prompt is available on the current card and the learner swipes to another card instead of opening it
- **THEN** the app advances through the existing local card-selection flow without recording a speaking attempt

#### Scenario: Speaking sync is pending
- **WHEN** speaking event sync is pending or in progress
- **THEN** the app still selects the next card locally without awaiting the speaking sync operation

