## MODIFIED Requirements

### Requirement: Backend accepts study event with difficulty rating

The system SHALL accept and store a difficulty rating when a user submits a rating study event. Ratings drive automatic proficiency level changes. Speaking study events are accepted through the sync contract as separate non-rating events and SHALL NOT require a difficulty rating.

#### Scenario: Study event submission includes rating
- **WHEN** mobile app submits a rating study event with fields: device_id, word_id, rating (easy|too_easy|hard|too_hard)
- **THEN** backend stores the rating and returns proficiency change details

#### Scenario: Rating field is required for rating events
- **WHEN** mobile app submits a rating study event without rating field
- **THEN** backend rejects request with HTTP 400 and specifies valid rating values

#### Scenario: Speaking event omits rating
- **WHEN** mobile app submits a valid speaking event with event_type and speaking metadata but without rating
- **THEN** backend accepts the speaking event through the speaking event path and does not update memory rating, review scheduling, or proficiency state

## ADDED Requirements

### Requirement: Study event sync accepts discriminated speaking events
The backend SHALL allow `POST /v1/study-events/sync` to process batches containing both rating events and speaking events while preserving existing response semantics for accepted, duplicate, and rejected event keys.

#### Scenario: Batch contains rating and speaking events
- **WHEN** mobile syncs a batch with one valid rating event and one valid speaking event
- **THEN** the backend stores the rating event through the existing rating path, stores the speaking event through the speaking event path, returns both event keys in `accepted_event_ids`, and returns proficiency based only on rating events

#### Scenario: Speaking event is invalid in mixed batch
- **WHEN** mobile syncs a batch with a valid rating event and an invalid speaking event
- **THEN** the backend accepts the valid rating event, rejects the invalid speaking event with a reason in `rejected_events`, and does not fail the entire batch
