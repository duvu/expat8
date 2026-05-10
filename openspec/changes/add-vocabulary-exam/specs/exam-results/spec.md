## ADDED Requirements

### Requirement: Backend persists exam attempt on submission
The system SHALL accept `POST /v1/exam/submit` with the session ID and the user's selected answer indices, validate answers against stored questions, calculate the score, and persist the result to `exam_attempts`.

#### Scenario: Valid submission is accepted
- **WHEN** `POST /v1/exam/submit` is called with a valid session ID and one answer index per question
- **THEN** the backend validates each answer, computes `correct_count / total_questions`, writes a row to `exam_attempts`, and returns the score summary

#### Scenario: Session not found
- **WHEN** `POST /v1/exam/submit` is called with an unknown session ID
- **THEN** the backend returns HTTP 404

#### Scenario: Session already submitted
- **WHEN** `POST /v1/exam/submit` is called on a session that has already been submitted
- **THEN** the backend returns HTTP 409 Conflict

#### Scenario: Answer count mismatch
- **WHEN** the number of answer indices in the submission does not match the number of questions in the session
- **THEN** the backend returns HTTP 422 with error code `ANSWER_COUNT_MISMATCH`

### Requirement: Exam attempt record includes full context
Each `exam_attempts` row SHALL store: user_id, session_id, topic, language, difficulty_level, total_questions, correct_count, score_pct, passed (boolean, threshold ≥ 70%), created_at.

#### Scenario: Attempt record is complete
- **WHEN** a submission is persisted
- **THEN** querying `exam_attempts` for that session_id returns a row with all required fields populated

### Requirement: User can retrieve their exam history
The system SHALL expose `GET /v1/exam/results` (paginated, newest first) returning the authenticated user's exam attempts. Each item includes: attempt_id, topic, language, difficulty_level, score_pct, passed, created_at, certificate_id (nullable).

#### Scenario: Results are returned newest-first
- **WHEN** `GET /v1/exam/results` is called by an authenticated user
- **THEN** the response contains attempts sorted by `created_at` descending

#### Scenario: Empty history
- **WHEN** the user has no exam attempts
- **THEN** `GET /v1/exam/results` returns an empty `items` array with `total: 0`

### Requirement: Exam results do not modify SRS state
The system SHALL NOT update `user_word_states`, emit study events, or alter SRS scheduling as part of exam submission processing.

#### Scenario: SRS state is unchanged after exam
- **WHEN** `POST /v1/exam/submit` completes successfully
- **THEN** `user_word_states` rows for the examined words are identical before and after the request
