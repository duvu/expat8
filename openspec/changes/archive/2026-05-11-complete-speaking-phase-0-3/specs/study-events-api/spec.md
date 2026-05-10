## MODIFIED Requirements

### Requirement: Backend accepts study event with difficulty rating

The system SHALL accept and store a difficulty rating when a user submits a study event. Ratings drive automatic proficiency level changes. The system SHALL also accept speaking event types which are stored without affecting proficiency.

#### Scenario: Study event submission includes rating
- **WHEN** mobile app submits a study event with fields: device_id, word_id, rating (easy|too_easy|hard|too_hard)
- **THEN** backend stores the rating and returns proficiency change details

#### Scenario: Rating field is required for rating event types
- **WHEN** mobile app submits a study event without rating field and event_type is not a speaking event type
- **THEN** backend rejects request with HTTP 400 and specifies valid rating values

#### Scenario: Speaking event types accepted without rating field
- **WHEN** mobile app submits an event with event_type in (speaking_prompt_viewed, speaking_sample_played, speaking_recorded, speaking_retried, speaking_self_rated_clear, speaking_self_rated_hesitated, speaking_self_rated_could_not_say, speaking_drill_completed)
- **THEN** backend accepts the event, stores it with metadata, and returns it in accepted_event_ids without requiring a rating field

## ADDED Requirements

### Requirement: Backend accepts full set of speaking funnel event types

The system SHALL validate and accept all 8 speaking event types as part of the study events sync endpoint.

#### Scenario: speaking_prompt_viewed accepted
- **WHEN** mobile submits event with event_type `speaking_prompt_viewed` and metadata containing prompt_id
- **THEN** backend stores the event and includes event key in `accepted_event_ids`

#### Scenario: speaking_sample_played accepted
- **WHEN** mobile submits event with event_type `speaking_sample_played` and metadata containing prompt_id
- **THEN** backend stores the event and includes event key in `accepted_event_ids`

#### Scenario: speaking_retried accepted
- **WHEN** mobile submits event with event_type `speaking_retried` and metadata containing attempt_id, retry_count
- **THEN** backend stores the event and includes event key in `accepted_event_ids`

#### Scenario: speaking_self_rated_hesitated accepted
- **WHEN** mobile submits event with event_type `speaking_self_rated_hesitated` and metadata containing attempt_id
- **THEN** backend stores the event and includes event key in `accepted_event_ids`

#### Scenario: speaking_self_rated_could_not_say accepted
- **WHEN** mobile submits event with event_type `speaking_self_rated_could_not_say` and metadata containing attempt_id
- **THEN** backend stores the event and includes event key in `accepted_event_ids`

#### Scenario: speaking_drill_completed accepted
- **WHEN** mobile submits event with event_type `speaking_drill_completed` and metadata containing prompts_attempted, prompts_completed, total_duration_ms
- **THEN** backend stores the event and includes event key in `accepted_event_ids`

#### Scenario: Unknown event types rejected
- **WHEN** mobile submits event with an event_type not in the known list
- **THEN** backend rejects with HTTP 400 and returns event key in `rejected_events` with reason "unknown_event_type"
