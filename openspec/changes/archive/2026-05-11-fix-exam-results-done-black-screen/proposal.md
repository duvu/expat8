## Why

After completing an exam and seeing results, tapping `Done` can leave the app on a black screen. The results screen still assumes the old route stack included a topic picker, but the current exam flow goes directly from learning screen to question screen and then replaces the question route with results.

## What Changes

- Change the `Done` action on `ExamResultsScreen` so it returns to the learning screen without popping the root route.
- Keep controller reset behavior when leaving results.
- Add widget coverage proving `Done` returns to the previous app screen and does not over-pop the navigator.
- Update stale comments that still mention topic-screen navigation.

## Capabilities

### New Capabilities

- `mobile-exam-navigation`: Mobile exam routes, results actions, and safe return-to-learning behavior.

### Modified Capabilities

_(none)_

## Impact

- **Mobile**: `mobile/lib/src/exam/exam_results_screen.dart` navigation handler for `Done`.
- **Mobile tests**: `mobile/test/exam_results_screen_test.dart` adds a regression test for the `Done` action.
- **Backend/API/Database**: no changes.
