## Purpose
Define how the mobile learning session selects cards, handles gestures, updates local learning state, and renders language-native proficiency labels.
## Requirements
### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where horizontal swipes advance through a 15% new-card / 85% review-card session mix, vertical swipes persist study activity for the current card, and session navigation stays scoped to the active learning language and proficiency scale. Card selection SHALL never await or invoke any server request; background inventory maintenance and background study-event sync are the only permitted network paths from swipe handling. Gesture dispatch MUST be single-flight so one recognized gesture is processed at a time.

#### Scenario: User swipes right-to-left for the next mixed card
- **WHEN** the user performs a right-to-left swipe on the learning screen
- **THEN** the app requests the next card through the 15% new-card / 85% review-card selector using the active language and current scale-native proficiency state

#### Scenario: User swipes left-to-right for review
- **WHEN** the user performs a left-to-right swipe on the learning screen
- **THEN** the app requests a review-first selection using the active language and current scale-native proficiency state while preserving fallback to another available card type

#### Scenario: User swipes vertically on current card
- **WHEN** the user performs a vertical swipe on the current card
- **THEN** the app writes the corresponding local study event and local learning-state transition before advancing to another locally selected card without showing an empty card while any learned or new fallback card exists

#### Scenario: Remembered swipe records a strong positive study action
- **WHEN** the user performs a bottom-to-top swipe on the current card
- **THEN** the app records a local `too_easy` study event, applies the remembered low-frequency local transition, schedules background sync, and advances locally without awaiting the network

#### Scenario: Difficult swipe records a strong negative study action
- **WHEN** the user performs a top-to-bottom swipe on the current card
- **THEN** the app records a local `too_hard` study event, applies the difficult relearn local transition, schedules background sync, and advances locally without awaiting the network

#### Scenario: Rapid duplicate gestures are ignored while one gesture is active
- **WHEN** a recognized gesture callback is still in progress and the user performs another swipe
- **THEN** the app ignores the duplicate gesture until the active gesture completes and MUST NOT duplicate the current card's local study event or local learning-state transition

#### Scenario: Gesture callback fails
- **WHEN** a gesture callback fails while processing a recognized swipe
- **THEN** the app handles the failure without leaving gesture dispatch permanently disabled and allows a later gesture to be processed

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app restores session state including active language and associated proficiency scale metadata before continuing the session

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
The mobile app SHALL allow the user to submit a memory rating, including gesture-submitted remembered and difficult study actions, and SHALL update local proficiency state from backend scale-native responses when those responses are available.

#### Scenario: User rates a card
- **WHEN** the user submits a rating for the current card
- **THEN** the app records the rating locally and applies returned `proficiency.scale`, `proficiency.level`, and `proficiency.level_index` to session state when the backend response is available

#### Scenario: User rates a card through a vertical gesture while offline
- **WHEN** the user submits a remembered or difficult vertical swipe and the backend is unavailable
- **THEN** the app records the study event locally, keeps it queued for retry, applies the local learning-state transition, and continues the session without blocking on sync

#### Scenario: Proficiency level changes
- **WHEN** the backend reports a level change after rating submission or study-event sync
- **THEN** the app updates the displayed level label according to the returned scale without assuming CEFR-only semantics

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
