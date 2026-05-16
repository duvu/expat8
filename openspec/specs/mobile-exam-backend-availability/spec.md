## ADDED Requirements

### Requirement: Exam start checks backend readiness before opening an exam session
The mobile app SHALL verify backend readiness before attempting to start an exam session, and SHALL only request exam questions if the backend readiness probe succeeds.

#### Scenario: Backend is healthy
- **WHEN** the user taps `Take Exam` and the backend readiness probe reports healthy
- **THEN** the app starts the exam session normally and navigates to the question screen

#### Scenario: Backend is unavailable
- **WHEN** the user taps `Take Exam` and the backend readiness probe fails or reports unhealthy
- **THEN** the app does not call `POST /v1/exam/start`, stays on the exam entry screen, and shows a retryable backend-unavailable message

### Requirement: Exam start failures surface a retryable connectivity error
The mobile app SHALL present a specific retryable error when the exam start request fails because the backend cannot be reached or becomes unavailable after readiness passed.

#### Scenario: Start request fails after readiness probe
- **WHEN** the readiness probe succeeds but `POST /v1/exam/start` fails due to network failure or backend unavailability
- **THEN** the app remains out of the exam flow and shows a retryable failure message

#### Scenario: User retries after failure
- **WHEN** the user dismisses the failure and taps `Take Exam` again after the backend recovers
- **THEN** the app retries the readiness probe and can start the exam session successfully
