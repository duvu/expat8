## Why

After completing a vocabulary exam, the Results screen displays an infinite spinner and never shows the score. This blocks users from seeing their exam outcome and makes the exam feature unusable. The root cause is a widget architecture bug: `ExamResultsScreen` is a `StatelessWidget` with no controller listener, so it cannot rebuild when the exam result arrives asynchronously.

## What Changes

- Convert `ExamResultsScreen` from `StatelessWidget` to `StatefulWidget` (or wrap with `ListenableBuilder`) so it rebuilds when `controller.result` becomes non-null
- Remove the silent failure path in `ExamQuestionScreen._onControllerChanged` where `if (!mounted) return` swallows navigation to the results screen when the widget is disposed during submission
- Add error handling in `ExamResultsScreen` for the case where submission fails (currently shows spinner forever; should show an error message with retry option)
- Add a timeout guard so the spinner never shows indefinitely regardless of network or controller state

## Capabilities

### New Capabilities

_(none — this is a bug fix with no new user-facing capability)_

### Modified Capabilities

- `vocabulary-exam`: The exam results screen now reliably renders after submission completes, and handles submission failure gracefully instead of hanging indefinitely.

## Impact

- `mobile/lib/src/exam/exam_results_screen.dart`: converted to reactive widget
- `mobile/lib/src/exam/exam_question_screen.dart`: navigation to results made resilient
- `mobile/lib/src/exam/exam_session_controller.dart`: error state exposed for results screen to consume
- No backend changes required; no API contract changes; no ObjectBox schema changes
