## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where horizontal swipes advance through a 15% new-card / 85% review-card session mix, vertical swipes update the current card's local learning state, and session navigation stays scoped to the active learning language and proficiency scale. Card selection SHALL never await or invoke any server request; background inventory maintenance is the only permitted network path.

#### Scenario: User swipes right-to-left for the next mixed card
- **WHEN** the user performs a right-to-left swipe on the learning screen
- **THEN** the app requests the next card through the 15% new-card / 85% review-card selector using the active language and current scale-native proficiency state

#### Scenario: User swipes left-to-right for review
- **WHEN** the user performs a left-to-right swipe on the learning screen
- **THEN** the app requests a review-first selection using the active language and current scale-native proficiency state while preserving fallback to another available card type

#### Scenario: User swipes vertically on current card
- **WHEN** the user performs a vertical swipe on the current card
- **THEN** the app updates the current card's local learning state and advances to another locally selected card without showing an empty card while any learned or new fallback card exists

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app restores session state including active language and associated proficiency scale metadata before continuing the session

#### Scenario: Card selection never blocks on network
- **WHEN** the app selects the next card and a background refill is in progress or pending
- **THEN** the app returns a card from local storage immediately without awaiting the network operation

#### Scenario: New-word shown triggers post-transition refill check
- **WHEN** a new-word card is shown and the user advances to it
- **THEN** the app fires `markWordAsLearning` in the background, and the inventory threshold check runs after that transition completes — not before
