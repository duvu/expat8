# vocabulary-exam Specification

## Purpose
TBD - created by archiving change fix-exam-results-hang. Update Purpose after archive.
## Requirements
### Requirement: Exam results screen renders reactively

The results screen SHALL listen to the exam session controller and rebuild whenever the controller notifies, so the score and pass/fail status appear as soon as the submission completes — even if the screen was constructed before the HTTP response arrived.

#### Scenario: Result arrives after screen is constructed
- **WHEN** `ExamResultsScreen` is pushed while `controller.result` is still null (submission in flight)
- **THEN** the screen displays a loading spinner until `controller.result` becomes non-null, then rebuilds automatically to show the score and pass/fail outcome without any user action

#### Scenario: Result already available when screen is constructed
- **WHEN** `ExamResultsScreen` is constructed with `controller.result` already non-null
- **THEN** the screen immediately renders the score circle, pass/fail message, and action buttons with no intermediate spinner

### Requirement: Exam results screen handles submission failure gracefully

When exam submission fails while the results screen is the active screen, the system SHALL display an actionable error message instead of an infinite spinner.

#### Scenario: Submission fails while results screen is shown
- **WHEN** `controller.state` transitions to `ExamState.active` with a non-null `errorMessage` while `ExamResultsScreen` is active and `controller.result` is null
- **THEN** the screen replaces the spinner with an error message (the controller's `errorMessage`) and a "Try Again" button visible to the user

#### Scenario: Try Again returns to topic screen
- **WHEN** user taps "Try Again" on the results error UI
- **THEN** the app calls `controller.reset()` and navigates back to the exam topic selection screen

### Requirement: Exam results screen times out gracefully

The results screen SHALL never display an infinite spinner. If no result has arrived within 20 seconds of the screen being shown, the system SHALL display a timeout error with a retry option.

#### Scenario: Submission stalls beyond 20 seconds
- **WHEN** `ExamResultsScreen` is shown and `controller.result` remains null for more than 20 seconds
- **THEN** the spinner is replaced with a timeout error message ("Exam submission timed out. Please try again.") and a "Try Again" button

#### Scenario: Result arrives before timeout
- **WHEN** `controller.result` becomes non-null within 20 seconds of the results screen being shown
- **THEN** the timeout timer is cancelled and the results UI is displayed normally; no timeout error is shown

