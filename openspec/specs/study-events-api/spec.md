## ADDED Requirements

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

The backend SHALL handle duplicate submissions and out-of-order events correctly, recomputing proficiency thresholds from database. The batch sync response SHALL use the field names `accepted_event_ids` (array of newly accepted event keys), `rejected_events` (array of rejected event objects with `client_event_id`, `event_id`, and `reason`), and `duplicates` (array of event keys that were already recorded). The legacy field names `accepted` and `rejected` are removed.

#### Scenario: Duplicate submission doesn't double-count
- **WHEN** the same event is submitted twice via `POST /v1/study-events/sync`
- **THEN** backend recognizes it as duplicate, doesn't create a duplicate record, returns the event key in `duplicates`, and returns an empty `accepted_event_ids`

#### Scenario: Out-of-order events processed correctly
- **WHEN** a batch arrives with events that have mixed `occurred_at` timestamps
- **THEN** the backend processes them in chronological order and returns all event keys in `accepted_event_ids`

#### Scenario: Sync response uses correct field names
- **WHEN** `POST /v1/study-events/sync` processes a batch with one new event, one duplicate, and one invalid
- **THEN** the response contains `accepted_event_ids: [<new>]`, `duplicates: [<duplicate>]`, `rejected_events: [{ client_event_id, event_id, reason }]`, and `proficiency`

#### Scenario: Both event_id and client_event_id are accepted as event keys
- **WHEN** an event is submitted with only `event_id` (no `client_event_id`)
- **THEN** the backend uses `event_id` as the deduplication key and includes it in `accepted_event_ids`

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
