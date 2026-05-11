## Context

The exam flow no longer has a topic picker. `LearningScreen._openExam()` starts a language-scoped session and pushes `ExamQuestionScreen`; when the last answer is submitted, `ExamQuestionScreen` uses `pushReplacement()` to show `ExamResultsScreen`.

That means the active navigator stack at results time is effectively `LearningScreen -> ExamResultsScreen`. `ExamResultsScreen` still treats `Done` as if the stack were `LearningScreen -> TopicScreen -> ResultsScreen` and calls `Navigator.pop()` twice. The first pop returns to learning; the second pop removes the learning route, leaving the app with a blank/black screen.

## Goals / Non-Goals

**Goals:**
- Make `Done` return safely to the learning screen from the current exam route stack.
- Preserve controller reset when leaving results.
- Add a regression test that fails if `Done` over-pops the navigator.
- Clean up stale comments that mention topic-screen navigation.

**Non-Goals:**
- Changing exam scoring, submission, certificate rendering, or backend behavior.
- Reintroducing the topic picker.
- Changing `Take Again` behavior beyond stale comment cleanup unless testing reveals it also over-pops.

## Decisions

### Use one safe pop for `Done`

The minimal fix is to replace the double-pop handler with a single navigation back to the previous route. In the current flow, results is the only exam route left because question was replaced by results.

**Alternative considered**: `Navigator.popUntil((route) => route.isFirst)`. This is also safe against route-stack changes, but it is broader than necessary and may skip intermediate routes if future flows intentionally add one.

### Keep controller reset before leaving

The existing `Done` action resets the controller. Keep that behavior so returning to learning cannot expose stale exam state if the same controller reference is retained longer than expected.

### Add widget regression coverage

Add a test that pushes `ExamResultsScreen` on top of a home route, taps `Done`, and asserts the home route remains visible. This directly covers the black-screen failure mode caused by popping the root route.

## Risks / Trade-offs

- **Risk**: Future exam flows may add another intermediate route. → The test should document the intended current stack, and future changes can update the navigation contract deliberately.
- **Risk**: `Navigator.pop()` on a route that cannot pop would be a no-op or close the app on some platforms. → Results screen is only reached by push/replacement from learning in the current app flow.
