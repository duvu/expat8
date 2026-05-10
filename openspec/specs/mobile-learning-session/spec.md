## Purpose
Define how the mobile learning session selects cards, handles gestures, updates local learning state, and renders language-native proficiency labels.
## Requirements
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

#### Scenario: Rapid duplicate gestures are ignored while one gesture is active
- **WHEN** a recognized gesture callback is still in progress and the user performs another swipe
- **THEN** the app ignores the duplicate gesture until the active gesture completes and MUST NOT duplicate the current card's local study event or local learning-state transition

#### Scenario: Gesture callback fails
- **WHEN** a gesture callback fails while processing a recognized swipe
- **THEN** the app handles the failure without leaving gesture dispatch permanently disabled and allows a later gesture to be processed

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app loads the most recent local learning state before starting the session and records initialization log events for restored state

#### Scenario: Card selection never blocks on network
- **WHEN** the app selects the next card and a background refill is in progress or pending
- **THEN** the app returns a card from local storage immediately without awaiting the network operation

#### Scenario: New-word shown triggers post-transition refill check
- **WHEN** a new-word card is shown and the user advances to it
- **THEN** the app fires `markWordAsLearning` in the background, and the inventory threshold check runs after that transition completes — not before

### Requirement: Vocabulary card displays required learning content
The mobile app SHALL display all required vocabulary fields on each card when the data is available.

#### Scenario: Complete vocabulary card is shown
- **WHEN** a vocabulary card is displayed
- **THEN** the card includes the term, Vietnamese meaning, Vietnamese-friendly pronunciation, IPA, example sentence, and Vietnamese example translation

#### Scenario: Optional part of speech is available
- **WHEN** a vocabulary item includes part of speech
- **THEN** the card displays the part of speech with the vocabulary term

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
