## ADDED Requirements

### Requirement: Record difficulty rating on study events

The system SHALL accept and store a difficulty rating (`easy`, `too_easy`, `hard`, `too_hard`) when a user submits a study event.

#### Scenario: Submit study event with rating
- **WHEN** client calls `POST /v1/study-events` with `rating` field set to "too_easy"
- **THEN** system stores the rating in `study_events.rating` column

#### Scenario: Rating field is required
- **WHEN** client calls `POST /v1/study-events` without `rating` field
- **THEN** system rejects the request with HTTP 400 and error message

### Requirement: Return proficiency impact in response

The system SHALL return proficiency change details in the study event response.

#### Scenario: Response includes level change status
- **WHEN** client submits study event that triggers a level change (5th consecutive same rating)
- **THEN** response includes:
  - `proficiency.level`: new proficiency level (e.g., "A2")
  - `proficiency.level_changed`: true
  - `proficiency.previous_level`: previous level (e.g., "A1")
  - `proficiency.triggered_by`: description (e.g., "5x consecutive too_easy")

#### Scenario: Response when no level change
- **WHEN** client submits study event that does not trigger level change
- **THEN** response includes:
  - `proficiency.level`: current level
  - `proficiency.level_changed`: false
  - `proficiency.consecutive_count`: current position toward threshold (e.g., 3)
  - `proficiency.consecutive_rating_type`: current rating type being counted (e.g., "too_easy")

### Requirement: Support four difficulty rating types

The system SHALL accept exactly four rating types: `easy`, `too_easy`, `hard`, `too_hard`.

#### Scenario: Accept valid ratings
- **WHEN** client submits rating of "easy", "too_easy", "hard", or "too_hard"
- **THEN** system accepts the submission

#### Scenario: Reject invalid ratings
- **WHEN** client submits rating of "medium", "neutral", or any other value
- **THEN** system rejects with HTTP 400 and lists valid rating types

### Requirement: Semantics of each rating

- `easy`: Word was easy to understand; learner could handle it
- `too_easy`: Word was too easy; learner is ready for harder content (triggers level-up)
- `hard`: Word was difficult; learner found it challenging (triggers level-down)
- `too_hard`: Word was impossibly difficult; learner was overwhelmed (no level change, but tracked for analytics)

#### Scenario: Rating semantics are clear
- **WHEN** system documents or displays rating options to users
- **THEN** each rating includes the description above to guide learner choice
