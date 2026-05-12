## Purpose
Define the backend API for accepting and persisting study events submitted by mobile clients.
## Requirements
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

### Requirement: Backend returns proficiency response on study event submission

The backend SHALL return the current proficiency level and any level changes in the study event response.

#### Scenario: Level changed (5 consecutive same ratings)
- **WHEN** user submits 5th consecutive "too_easy" or "hard" rating
- **THEN** response includes:
  - proficiency.level: new CEFR level (A1–C2)
  - proficiency.level_changed: true
  - proficiency.previous_level: prior level
  - proficiency.triggered_by: description (e.g., "5x consecutive too_easy")

#### Scenario: No level change
- **WHEN** rating is submitted but does not reach threshold (5 consecutive)
- **THEN** response includes:
  - proficiency.level: current level
  - proficiency.level_changed: false
  - proficiency.consecutive_count: progress toward threshold (0–4)
  - proficiency.consecutive_rating_type: rating type being counted (e.g., "too_easy")

### Requirement: Difficulty ratings follow defined semantics

The system SHALL interpret ratings as follows:
- `easy`: Word was easy; learner understood it
- `too_easy`: Word was too easy; learner is ready for harder content (triggers level-up on 5 consecutive)
- `hard`: Word was difficult; learner found it challenging (triggers level-down on 5 consecutive)
- `too_hard`: Word was impossible; learner was overwhelmed (no level change but tracked for analytics)

#### Scenario: "Too Easy" triggers level advancement when consecutive
- **WHEN** user marks 5 words in a row as "too_easy"
- **THEN** proficiency level increases by 1 step (A1→A2, B1→B2, etc.)

#### Scenario: "Hard" triggers level regression when consecutive
- **WHEN** user marks 5 words in a row as "hard"
- **THEN** proficiency level decreases by 1 step (B1→A2, C2→C1, etc.)

#### Scenario: "Easy" and "Too Hard" don't trigger level changes
- **WHEN** user marks multiple words as "easy" or "too_hard"
- **THEN** no proficiency level change occurs (ratings are recorded but don't meet threshold conditions)

### Requirement: Study event stores device identifier for proficiency tracking

The backend SHALL associate study events with a device_id to track and update that device's proficiency level.

#### Scenario: Study event linked to device proficiency
- **WHEN** backend processes study event with device_id
- **THEN** backend updates user_proficiency record for that device_id with new level if threshold is met

### Requirement: Idempotency and out-of-order handling
The backend SHALL treat each study event identifier as an idempotency key, SHALL classify sync outcomes as accepted/duplicate/rejected, and SHALL apply deterministic projection order for out-of-order arrivals.

#### Scenario: Duplicate submission doesn't double-count
- **WHEN** mobile app retries the same study event (same client_event_id or event_id)
- **THEN** backend recognizes it as duplicate, does not create a second event, and returns duplicate classification in sync response

#### Scenario: Out-of-order events processed deterministically
- **WHEN** events arrive out of sequence due to offline replay or retry
- **THEN** backend applies projection using deterministic ordering `(occurred_at, received_at, event_id)` to update SRS state consistently

#### Scenario: Unknown references are rejected without aborting batch
- **WHEN** a sync batch includes an event with unknown word reference
- **THEN** backend marks that event rejected with reason and continues processing other valid events in the same batch

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

### Requirement: Study event sync accepts discriminated speaking events
The backend SHALL allow `POST /v1/study-events/sync` to process batches containing both rating events and speaking events while preserving existing response semantics for accepted, duplicate, and rejected event keys.

#### Scenario: Batch contains rating and speaking events
- **WHEN** mobile syncs a batch with one valid rating event and one valid speaking event
- **THEN** the backend stores the rating event through the existing rating path, stores the speaking event through the speaking event path, returns both event keys in `accepted_event_ids`, and returns proficiency based only on rating events

#### Scenario: Speaking event is invalid in mixed batch
- **WHEN** mobile syncs a batch with a valid rating event and an invalid speaking event
- **THEN** the backend accepts the valid rating event, rejects the invalid speaking event with a reason in `rejected_events`, and does not fail the entire batch

