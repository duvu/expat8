## 1. Backend readiness probe

- [x] 1.1 Add an unauthenticated `GET /health/ready` helper to `BackendApiClient` that returns a simple healthy/unhealthy result without app-credential headers.
- [x] 1.2 Add `backend_api_client_test.dart` coverage for the readiness probe request shape and a healthy response.

## 2. Exam startup gating

- [x] 2.1 Update `ExamSessionController.startSession()` to preflight backend readiness before calling `startExamSession()`.
- [x] 2.2 Keep existing `INSUFFICIENT_WORDS` handling intact while mapping readiness or network failures to a retryable backend-unavailable error and leaving the controller idle.
- [x] 2.3 Confirm the healthy path still transitions to `ExamState.active` and preserves the existing question flow after the readiness check passes.

## 3. UI and regression tests

- [x] 3.1 Extend `exam_session_controller_test.dart` for healthy readiness, probe failure, start failure after readiness, and retry-after-recovery behavior.
- [x] 3.2 Add or update a `learning_screen_test.dart` case proving `Take Exam` stays on the learning screen and surfaces the retryable error when the backend is unavailable.
- [x] 3.3 Run the focused mobile test files for the API client, exam controller, and learning screen.

## 4. Verification

- [x] 4.1 Manually verify on the emulator that `Take Exam` starts normally when the backend is healthy.
- [x] 4.2 Manually verify the failure path by making the backend unavailable and confirming the app shows the retryable connectivity message without entering the exam.
