## Context

`ExamResultsScreen` (`mobile/lib/src/exam/exam_results_screen.dart`) is a `StatelessWidget`. Its `build()` method reads `controller.result` once and, if null, renders `CircularProgressIndicator` with no mechanism to ever leave that state. The widget never registers a listener on the controller.

Navigation to `ExamResultsScreen` is driven by `ExamQuestionScreen._onControllerChanged()` (`exam_question_screen.dart:39–52`), which calls `Navigator.pushReplacement` when `controller.state == ExamState.results`. Because `ExamResultsScreen` has no listener, it can only render correctly if `controller.result` is already set at the exact moment of the first `build()` call. If that assumption is violated for any reason (timing edge, double-tap, hot-reload, race during `pushReplacement` animation), the spinner is permanent.

There is no timeout, no error path, and no retry: the user has no way to recover without force-closing the app.

## Goals / Non-Goals

**Goals:**
- `ExamResultsScreen` rebuilds whenever `controller.result` or `controller.state` changes, eliminating the permanent-spinner scenario
- If `controller.state` is `ExamState.active` (submission failed) when results screen is shown, display an error message with a "Try Again" button instead of a spinner
- If result has not arrived within a configurable timeout (default 20 s), display a timeout error with retry instead of hanging indefinitely
- All existing happy-path behaviour (score circle, certificate banner, "Take Again", "Done") is unchanged

**Non-Goals:**
- Redesigning the exam UI or scoring logic
- Changing the backend API contract
- Adding offline submission support
- Migrating `ExamSessionController` away from `ChangeNotifier`

## Decisions

### 1. Wrap `ExamResultsScreen` body in `ListenableBuilder` rather than converting to `StatefulWidget`

`ListenableBuilder(listenable: controller, builder: ...)` re-renders the body on every `notifyListeners()` call with no boilerplate `addListener`/`removeListener` in lifecycle methods. The widget stays a `StatelessWidget`. This is the idiomatic Flutter pattern for reactive reads of a `ChangeNotifier` without full state management.

**Alternative considered:** Convert to `StatefulWidget` with `addListener(_rebuild)` in `initState` and `removeListener` in `dispose`. Achieves the same result but is more verbose and error-prone (easy to forget the `removeListener`). Rejected in favour of `ListenableBuilder`.

### 2. Expose submission failure in the results screen rather than forcing the user back to the question screen

Currently, submission errors set `_state = ExamState.active` and show a snackbar on `ExamQuestionScreen`. If the question screen is no longer in the tree (e.g., after a rapid pushReplacement or if the back stack was already cleared), the snackbar is never shown. The results screen should inspect `controller.state` and render an error UI (message + retry button) when state is `active` with a non-null `errorMessage`, rather than always deferring to the question screen.

**Alternative considered:** Navigate back to `ExamQuestionScreen` on error from `ExamResultsScreen`. Rejected — after `pushReplacement` the question screen is gone from the navigator stack; reconstructing it would require the full session state to be intact, which is fragile.

### 3. Add a 20-second wall-clock timeout inside `ExamResultsScreen`

Use `Future.delayed` started in `initState` (or via a `StatefulWidget` shell around `ListenableBuilder`) to fire after 20 s. If `controller.result` is still null at that point, set a local `_timedOut` flag and call `setState`, rendering an error UI with retry. The retry button calls `controller.reset()` and pops to the topic screen.

**Alternative considered:** Add the timeout inside `ExamSessionController.submitSession`. Rejected — the controller already has `.timeout(timeout)` on the HTTP call. A second timeout on the widget side is a defensive belt-and-suspenders guard for scenarios where the controller gets stuck before or after the HTTP call.

**Implementation note:** Because we need `initState` for the timer, `ExamResultsScreen` will become a `StatefulWidget`. `ListenableBuilder` handles the reactive render inside `build`; the `StatefulWidget` shell only manages the timer.

## Risks / Trade-offs

- **Double rebuild on arrival**: `ListenableBuilder` rebuilds on every `notifyListeners()`. During submission, the controller may call `notifyListeners()` several times (submitting → results). Each rebuild is cheap (one null check + conditional render), so this is acceptable.
- **Timer resource**: `Timer` must be cancelled in `dispose` to avoid calling `setState` on an unmounted widget. This is straightforward.
- **Retry from results screen pops to topic screen**: `controller.reset()` followed by `Navigator.pop()` returns the user to `ExamTopicScreen`, which is the correct recovery flow. The partial answer state is lost, which is the expected behaviour on a failed submission.

## Migration Plan

1. Convert `ExamResultsScreen` to `StatefulWidget`; add `_timedOut` bool and a `Timer`; start timer in `initState`, cancel in `dispose`.
2. Wrap the body of `build` in `ListenableBuilder(listenable: widget.controller, ...)`.
3. Inside the builder, check states in order: `result != null` → show results UI (existing code); `timedOut || controller.state == active` → show error UI with retry; otherwise → show spinner (genuinely waiting).
4. Add `_onRetry()` method: calls `widget.controller.reset()` then `Navigator.pop(context)`.
5. Run `flutter test` to confirm all existing exam widget tests pass unchanged.
6. Manual regression: complete a full exam on emulator and confirm results appear immediately.

## Open Questions

_(none — root cause and fix are well-understood)_
