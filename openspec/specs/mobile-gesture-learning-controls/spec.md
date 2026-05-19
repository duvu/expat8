## Purpose
Define that mobile learning interactions are exclusively gesture-driven, with no explicit action buttons on the primary learning screen.
## Requirements
### Requirement: Learning interactions SHALL be gesture-only across all learning screens
The mobile app MUST remove explicit learning action buttons from all learning screens, including vocabulary and workplace sentence flows, and SHALL process learning intents exclusively from directional swipe gestures.

#### Scenario: Vocabulary learning screen renders without action buttons
- **WHEN** the user opens a vocabulary learning screen
- **THEN** the app displays the active card without rating/action buttons and accepts swipe gestures as the only card-action input

#### Scenario: Sentence learning screen renders without action buttons
- **WHEN** the user opens the workplace sentence learning screen
- **THEN** the app displays the active sentence card without action buttons and accepts swipe gestures as the only card-action input

### Requirement: Swipe directions SHALL map to defined study intents across all learning screens
The app SHALL map directional swipes to deterministic intents across vocabulary and sentence learning screens: right-to-left marks the current item as learned, appends it to the ordered history trail, and advances to another card using the 15% new / 85% re-learned selection policy; left-to-right opens the ordered history view; bottom-to-top marks the current item as remembered and removes it from further relearning; top-to-bottom marks the current item as difficult and schedules it for later relearning.

#### Scenario: User swipes right-to-left
- **WHEN** a right-to-left swipe is detected on the current item
- **THEN** the app marks the item as learned, appends it to the local history trail, and transitions to the next card using the shared 15% new / 85% re-learned selection policy

#### Scenario: User swipes left-to-right
- **WHEN** a left-to-right swipe is detected on the current item
- **THEN** the app opens the history view instead of advancing the session

#### Scenario: User swipes bottom-to-top
- **WHEN** a bottom-to-top swipe is detected on the current item
- **THEN** the app updates local state as remembered and excludes that item from further relearning

#### Scenario: User swipes top-to-bottom
- **WHEN** a top-to-bottom swipe is detected on the current item
- **THEN** the app updates local state as difficult and schedules the item for relearning later

### Requirement: Gesture activities SHALL persist via local database first
All gesture-generated learning activities, local history ordering, and derived progress counters MUST read from and write to local database state before any backend synchronization attempt.

#### Scenario: Gesture triggers local write path
- **WHEN** the user performs any learning swipe
- **THEN** the app persists the resulting state transition in local storage and only then schedules background sync if needed

