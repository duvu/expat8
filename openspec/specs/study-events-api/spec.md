## ADDED Requirements

### Requirement: Backend accepts study event with difficulty rating

The system SHALL accept and store a difficulty rating when a user submits a study event. Ratings drive automatic proficiency level changes.

#### Scenario: Study event submission includes rating
- **WHEN** mobile app submits a study event with fields: device_id, word_id, rating (easy|too_easy|hard|too_hard)
- **THEN** backend stores the rating and returns proficiency change details

#### Scenario: Rating field is required
- **WHEN** mobile app submits a study event without rating field
- **THEN** backend rejects request with HTTP 400 and specifies valid rating values

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

The backend SHALL handle duplicate submissions and out-of-order events correctly, recomputing proficiency thresholds from database.

#### Scenario: Duplicate submission doesn't double-count
- **WHEN** mobile app retries the same study event (same client_event_id)
- **THEN** backend recognizes it as duplicate, doesn't create duplicate record, and returns the same proficiency response

#### Scenario: Out-of-order events processed correctly
- **WHEN** events arrive out of sequence (e.g., due to network retry)
- **THEN** backend recomputes consecutive count from actual event history to determine proficiency changes accurately
