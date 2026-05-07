## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where horizontal swipes advance through a 15% new-card / 85% review-card session mix, vertical swipes update the current card's local learning state, and session navigation stays scoped to the active learning language and proficiency scale.

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

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Session targets three new words and seven review words
**Reason**: The target mix has changed from 30% new cards to 15% new cards.
**Migration**: Use `Session targets fifteen percent new cards and eighty-five percent review cards` for learning-session mix behavior.
