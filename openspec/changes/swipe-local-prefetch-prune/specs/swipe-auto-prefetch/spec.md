## ADDED Requirements

### Requirement: Swipe triggers background auto-prefetch when unlearned words are low
The mobile app SHALL check the local unlearned word count after every swipe (new word or review) and SHALL trigger a background prefetch of 100 words when the count is below 100.

#### Scenario: Unlearned count drops below threshold after swipe
- **WHEN** the user performs a swipe (new word or review) and the local unlearned word count is below 100
- **THEN** the app triggers a background prefetch of up to 100 new words from the backend without blocking the UI

#### Scenario: Unlearned count is at or above threshold after swipe
- **WHEN** the user performs a swipe and the local unlearned word count is 100 or more
- **THEN** the app does not trigger a prefetch

#### Scenario: Prefetch already in flight
- **WHEN** a swipe occurs while a background prefetch is already in progress
- **THEN** the app does not start a second prefetch

#### Scenario: Background prefetch fails
- **WHEN** a triggered background prefetch fails due to network error or backend timeout
- **THEN** the app silently discards the error and the UI is unaffected; the next swipe will re-evaluate and may trigger another attempt
