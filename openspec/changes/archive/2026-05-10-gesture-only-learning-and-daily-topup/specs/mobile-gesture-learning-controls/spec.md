## ADDED Requirements

### Requirement: Learning interactions SHALL be gesture-only
The mobile app MUST remove explicit learning action buttons from the primary learning screen and SHALL process learning intents exclusively from directional swipe gestures.

#### Scenario: Learning screen renders without action buttons
- **WHEN** the user opens the learning screen
- **THEN** the app displays the active vocabulary card without rating/action buttons and accepts swipe gestures as the only card-action input

### Requirement: Swipe directions SHALL map to defined study intents
The app SHALL map directional swipes to deterministic intents: right-to-left selects another card with 15% learned-word review weighting, left-to-right selects review flow with 15% new-word weighting, bottom-to-top marks remembered and lowers relearning frequency to 10%, and top-to-bottom marks difficult and adds the word to relearn group.

#### Scenario: User swipes right-to-left
- **WHEN** a right-to-left swipe is detected on the current card
- **THEN** the app transitions to another card and applies learned-word review targeting at 15% for subsequent selection decisions

#### Scenario: User swipes left-to-right
- **WHEN** a left-to-right swipe is detected on the current card
- **THEN** the app transitions to review flow and applies new-word targeting at 15% for subsequent selection decisions

#### Scenario: User swipes bottom-to-top
- **WHEN** a bottom-to-top swipe is detected on the current card
- **THEN** the app updates local word state as remembered, reduces relearning frequency for that word to 10%, and moves to the next card

#### Scenario: User swipes top-to-bottom
- **WHEN** a top-to-bottom swipe is detected on the current card
- **THEN** the app updates local word state as difficult, places the word into relearn group, and moves to the next card

### Requirement: Gesture activities SHALL persist via local database first
All gesture-generated learning activities MUST read from and write to local database state before any backend synchronization attempt.

#### Scenario: Gesture triggers local write path
- **WHEN** the user performs any learning swipe
- **THEN** the app persists the resulting state transition in local storage and only then schedules background sync if needed
