## ADDED Requirements

### Requirement: System records speaking events without audio payloads
The system SHALL accept and persist speaking behavior events that describe speaking practice metadata without including audio bytes or local audio file paths.

#### Scenario: Speaking recorded event is synced
- **WHEN** mobile syncs a `speaking_recorded` event with prompt ID, attempt ID, duration, retry count, self-rating state, and occurred-at timestamp
- **THEN** the backend persists the event metadata idempotently and does not require or store an audio payload

#### Scenario: Audio path is submitted accidentally
- **WHEN** a speaking event payload includes a local audio file path or raw audio data
- **THEN** the backend rejects or strips the forbidden field and MUST NOT persist the local path or raw audio data

### Requirement: Speaking events use a fixed event taxonomy
The system SHALL support a fixed set of speaking event types for phase 0-3 analytics and sync behavior.

#### Scenario: Supported speaking event type is accepted
- **WHEN** mobile syncs one of `speaking_prompt_viewed`, `speaking_sample_played`, `speaking_recorded`, `speaking_retried`, `speaking_self_rated_clear`, `speaking_self_rated_hesitated`, or `speaking_self_rated_could_not_say`
- **THEN** the backend accepts the event when required metadata is valid

#### Scenario: Unsupported speaking event type is rejected
- **WHEN** mobile syncs a speaking event with an unknown event type
- **THEN** the backend rejects that event with a validation reason and continues processing other valid events in the batch

### Requirement: Speaking event sync is idempotent
The system SHALL deduplicate speaking events by client event ID or event ID so retries do not inflate speaking metrics.

#### Scenario: Duplicate speaking event is synced
- **WHEN** the same speaking event is submitted more than once
- **THEN** the backend records it once, reports the later submission as duplicate, and does not increment spoken sentence or retry metrics again

### Requirement: Backend exposes weekly speaking summary metrics
The backend SHALL provide a weekly speaking summary for a device or signed-in user based on accepted speaking events.

#### Scenario: Weekly summary requested
- **WHEN** mobile requests the current weekly speaking summary for the active learner context
- **THEN** the backend returns spoken sentence count, retry count, self-rating counts, approximate speaking duration, and latest speaking activity timestamp
