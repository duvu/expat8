## ADDED Requirements

### Requirement: Speaking events include a client-generated attempt ID
Every speaking event submitted by the mobile client SHALL include an `attempt_id` field (UUID v4) that groups all events from a single drill session. The client generates this ID before the drill starts and attaches it to every event emitted during that session.

#### Scenario: Drill session begins
- **WHEN** the mobile client starts a new speaking drill
- **THEN** the client generates a UUID v4 as `attempt_id` and retains it for the duration of the drill

#### Scenario: Event submitted with attempt ID
- **WHEN** the client submits a speaking event (e.g., `speaking_prompt_completed`, `speaking_prompt_viewed`, `speaking_sample_played`) with a valid `attempt_id`
- **THEN** the backend accepts the event and persists it with the provided `attempt_id`

#### Scenario: Event submitted without attempt ID is rejected
- **WHEN** the client submits a speaking event that is missing `attempt_id`
- **THEN** the backend responds `400 { "error": "missing_required_field", "field": "attempt_id" }`

### Requirement: Backend accepts attempt ID as optional during transition window
During the period when old mobile clients without `attempt_id` are still in use, the backend SHALL accept speaking events missing `attempt_id` and store them with `attempt_id = null`, rather than rejecting them.

#### Scenario: Legacy client event without attempt ID
- **WHEN** a speaking event arrives without `attempt_id` and the transition-window flag is enabled
- **THEN** the backend persists the event with `attempt_id = null` and responds `200`

#### Scenario: Strict mode rejects missing attempt ID
- **WHEN** a speaking event arrives without `attempt_id` and the transition-window flag is disabled
- **THEN** the backend responds `400 { "error": "missing_required_field", "field": "attempt_id" }`
