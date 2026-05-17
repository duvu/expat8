## MODIFIED Requirements

### Requirement: User learning activities and related surfaces read from local database only
The mobile app MUST NOT call the backend API during user learning activities, history replay, or progress stats viewing.

#### Scenario: User swipes to next card
- **WHEN** the user performs any swipe gesture during a learning session
- **THEN** the app reads the next item from the local ObjectBox database without making a backend request

#### Scenario: User opens history view
- **WHEN** the user opens the history view from a learning screen
- **THEN** the app renders the ordered learned-item list from local ObjectBox data without making a backend request

#### Scenario: User opens stats page
- **WHEN** the user opens the learning progress stats page
- **THEN** the app calculates the visible counts from local ObjectBox data without making a backend request

#### Scenario: User marks an item as remembered
- **WHEN** the user swipes to mark an item as remembered (bottom-to-top)
- **THEN** the app updates the item's local state in ObjectBox only; no backend call is made synchronously

#### Scenario: User marks an item as difficult
- **WHEN** the user swipes to mark an item as difficult (top-to-bottom)
- **THEN** the app updates the item's local state in ObjectBox only; no backend call is made synchronously
