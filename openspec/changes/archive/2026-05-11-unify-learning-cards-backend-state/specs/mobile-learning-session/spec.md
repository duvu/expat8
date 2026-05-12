## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where a downward swipe requests the next vocabulary card through local selection backed by the unified `/v1/learning/cards` refill flow, and SHALL log session navigation actions and card-source decisions for troubleshooting.

#### Scenario: User swipes down for next card
- **WHEN** the user performs a downward swipe on the learning screen
- **THEN** the app selects and displays the next vocabulary card and records a session-navigation log event

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app loads the most recent local learning state before starting the session and records initialization log events for restored state

#### Scenario: Local new-word supply is low during navigation
- **WHEN** session navigation needs additional new-word supply
- **THEN** the app refills through `/v1/learning/cards` and does not call `/v1/words/next`

## ADDED Requirements

### Requirement: Session uses backend-owned new-word batches
The mobile learning session SHALL consume backend-owned new-word batches without sending current card IDs or word exclusion lists.

#### Scenario: New-word batch is requested
- **WHEN** the learning session requests new remote supply
- **THEN** the request uses the unified learning-card endpoint with limit 10 and omits current word ID and exclude word IDs

#### Scenario: Remote batch fails
- **WHEN** the unified learning-card endpoint fails during a session
- **THEN** the session continues with eligible local cards when available and does not fall back to the removed legacy endpoint
