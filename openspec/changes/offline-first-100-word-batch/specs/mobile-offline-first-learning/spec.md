## ADDED Requirements

### Requirement: Mobile loads vocabulary in batches of 100
The mobile app SHALL request exactly 100 vocabulary items per backend call when prefetching new words.

#### Scenario: Prefetch batch size is 100
- **WHEN** the app triggers a vocabulary prefetch
- **THEN** the app requests 100 words from the backend in a single call

#### Scenario: Backend returns up to 100 items
- **WHEN** the backend responds with up to 100 vocabulary items
- **THEN** the app stores all returned items in the local ObjectBox database

### Requirement: User learning activities read from local database only
The mobile app MUST NOT call the backend API during user learning activities (swipe gestures, word ratings).

#### Scenario: User swipes to next card
- **WHEN** the user performs any swipe gesture during a learning session
- **THEN** the app reads the next word from the local ObjectBox database without making a backend request

#### Scenario: User marks a word as remembered
- **WHEN** the user swipes to mark a word as remembered (bottom-to-top)
- **THEN** the app updates the word's local state in ObjectBox only; no backend call is made synchronously

#### Scenario: User marks a word as difficult
- **WHEN** the user swipes to mark a word as difficult (top-to-bottom)
- **THEN** the app updates the word's local state in ObjectBox only; no backend call is made synchronously

### Requirement: Backend is called only on low-watermark trigger
The mobile app SHALL call the backend to fetch new vocabulary only when the local unlearned word count falls below the configured low-watermark threshold.

#### Scenario: Local count is above watermark
- **WHEN** the local unlearned word count is above the low-watermark threshold
- **THEN** the app does not initiate a backend prefetch call

#### Scenario: Local count falls to or below watermark
- **WHEN** the local unlearned word count reaches or falls below the low-watermark threshold
- **THEN** the app initiates a background prefetch of 100 words from the backend
