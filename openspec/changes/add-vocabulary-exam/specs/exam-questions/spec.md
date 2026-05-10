## ADDED Requirements

### Requirement: Backend generates MCQ questions from user's studied word_senses
The system SHALL select source words from the `word_senses` rows that the user has studied (present in `user_word_states`), filtered by the requested topic and language, and build 4-choice questions where one choice is the correct definition and three are distractors.

#### Scenario: Questions are generated for a valid topic/language
- **WHEN** the backend receives `POST /v1/exam/start` with a valid topic, language, and user credential
- **THEN** it selects up to 20 studied words matching topic+language, generates one MCQ per word with 3 distractors, and returns the session ID and question list

#### Scenario: Distractors are drawn from same language and difficulty bucket
- **WHEN** generating distractors for a source word of difficulty D
- **THEN** the backend selects 3 words from the same language with difficulty within one level of D that the user has NOT already been shown as the source word in this session

#### Scenario: Fewer than 5 eligible source words
- **WHEN** fewer than 5 studied words match the requested topic and language
- **THEN** the backend returns HTTP 422 with an error code `INSUFFICIENT_WORDS` and a message indicating how many words were found

#### Scenario: Between 5 and 20 eligible source words
- **WHEN** between 5 and 20 studied words match the topic and language
- **THEN** the backend returns all eligible words as questions (not padded to 20)

### Requirement: Backend exposes a topic list endpoint filtered to user's studied words
The system SHALL provide `GET /v1/exam/topics?language=<lang>` that returns the distinct topics for which the authenticated user has at least one studied word in the given language.

#### Scenario: Topics returned for a language
- **WHEN** `GET /v1/exam/topics?language=en` is called with valid credentials
- **THEN** the backend returns a JSON array of distinct topic strings from the user's studied `en` word_senses

#### Scenario: No studied words for a language
- **WHEN** the user has no studied words for the requested language
- **THEN** the backend returns an empty array

### Requirement: Exam start request is authenticated with app-credential headers
The system SHALL require standard app-credential headers (`x-expat8-app-id`, `x-expat8-timestamp`, `x-expat8-nonce`, `x-expat8-content-sha256`, `x-expat8-signature`) on all exam endpoints. Unauthenticated requests SHALL be rejected with HTTP 401.

#### Scenario: Valid credentials provided
- **WHEN** a request includes valid app-credential headers
- **THEN** the backend processes the request normally

#### Scenario: Missing or invalid credentials
- **WHEN** a request is missing any required app-credential header or the signature is invalid
- **THEN** the backend returns HTTP 401 and does not generate questions

### Requirement: Exam question data is persisted per session
The system SHALL store each generated question (word_sense_id, choices, correct_index, session_id) in the `exam_questions` table so that results can be validated at submission time.

#### Scenario: Questions are stored on session start
- **WHEN** `POST /v1/exam/start` succeeds
- **THEN** all generated questions are written to `exam_questions` with the new session ID before the response is returned

#### Scenario: Stale exam sessions are not reused
- **WHEN** a session ID is older than 2 hours and has not been submitted
- **THEN** a `POST /v1/exam/submit` with that session ID returns HTTP 410 Gone
