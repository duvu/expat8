## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where horizontal swipe direction and visible new/review actions request the next vocabulary card from local storage, and SHALL trigger a background auto-prefetch check after every swipe, and failed requests SHALL produce visible feedback instead of silently keeping stale state.

#### Scenario: User requests a new word
- **WHEN** the user performs the configured new-word horizontal swipe or taps the visible new-word action on the learning screen
- **THEN** the app fetches the next vocabulary card from local storage and displays it

#### Scenario: User requests recent review
- **WHEN** the user performs the configured recent-review horizontal swipe or taps the visible review action on the learning screen
- **THEN** the app fetches a recently learned review card from local storage and displays it

#### Scenario: Swipe triggers prefetch check
- **WHEN** the user performs any swipe (new word or review) and a card is successfully displayed
- **THEN** the app checks the local unlearned word count in the background and triggers prefetch if count is below 100

#### Scenario: Gesture is too weak to classify
- **WHEN** the user performs a horizontal drag that does not meet the configured gesture threshold
- **THEN** the app either leaves the current card unchanged with a visible hint for valid actions or provides visible new/review buttons that remain usable

#### Scenario: Requested card is unavailable
- **WHEN** a new/review request cannot load a backend word or local fallback word
- **THEN** the app shows a visible no-card or error state instead of silently rendering the previous card as if nothing happened

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app loads the most recent local learning state before starting the session
