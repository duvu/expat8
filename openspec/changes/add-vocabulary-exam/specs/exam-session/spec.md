## ADDED Requirements

### Requirement: User can select a topic and language to start an exam
The system SHALL present the user with a list of topics (filtered to topics containing the user's studied words) and a language selector before starting an exam session.

#### Scenario: Topic list is populated
- **WHEN** the user opens the exam entry screen
- **THEN** the mobile app displays only topics for which the user has at least one studied word in the selected language

#### Scenario: Topic with no studied words is not shown
- **WHEN** the user has no studied words tagged with a given topic in the selected language
- **THEN** that topic does not appear in the exam topic list

#### Scenario: Minimum word count not met
- **WHEN** fewer than 5 studied words are available for the selected topic and language
- **THEN** the app shows an informational message and disables the start button

### Requirement: Exam session presents 4-choice MCQ questions sequentially
The system SHALL display one question at a time, each with exactly 4 answer choices. The user must select an answer before advancing.

#### Scenario: Question is displayed
- **WHEN** an exam session is active and the user is on a question
- **THEN** the screen shows the vocabulary word (or definition as prompt), 4 answer choices, and the current question number out of total

#### Scenario: User selects an answer
- **WHEN** the user taps an answer choice
- **THEN** the choice is highlighted and immediate per-question feedback is shown (correct/incorrect with the correct answer revealed)

#### Scenario: User advances to next question
- **WHEN** the user taps "Next" after viewing feedback
- **THEN** the session advances to the next question, or to the results screen if all questions are answered

### Requirement: Exam session is backed by a server-issued question set
The system SHALL obtain the question set from the backend via `POST /v1/exam/start` before displaying questions. No questions are generated client-side.

#### Scenario: Exam start request succeeds
- **WHEN** the user taps "Start Exam" with a valid topic and language selected
- **THEN** the mobile app calls `POST /v1/exam/start`, receives a session ID and question list, and transitions to the first question

#### Scenario: Exam start request fails
- **WHEN** `POST /v1/exam/start` returns an error or times out
- **THEN** the app shows an error message and returns the user to the topic selection screen without starting a session

### Requirement: Exam results screen shows score and certificate status
After answering all questions, the system SHALL display the total score (percentage correct), the number of correct answers, and — if the passing threshold was met — a certificate award notice with a share option.

#### Scenario: Passing score achieved
- **WHEN** the user answers all questions and the score is ≥ 70%
- **THEN** the results screen shows the score, a "Certificate Earned" banner, and a button to view or share the certificate

#### Scenario: Failing score
- **WHEN** the user answers all questions and the score is < 70%
- **THEN** the results screen shows the score and encourages the user to keep studying and retake the exam

### Requirement: ExamSessionController is separate from LearningSessionController
The system SHALL implement exam session state in a dedicated `ExamSessionController` class under `mobile/lib/src/exam/`. It SHALL NOT modify `LearningSessionController` or any SRS state.

#### Scenario: Exam session completes without SRS side-effects
- **WHEN** an exam session ends (pass or fail)
- **THEN** no `user_word_states` records are modified and no SRS rating events are emitted
