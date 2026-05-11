## 1. Results Navigation Fix

- [x] 1.1 Replace the `Done` double-pop handler in `mobile/lib/src/exam/exam_results_screen.dart` with a safe return to the learning screen
- [x] 1.2 Preserve `widget.controller.reset()` before dismissing the results route
- [x] 1.3 Update stale comments that still mention popping the topic screen

## 2. Regression Tests

- [x] 2.1 Add a widget test proving tapping `Done` returns to the underlying home/learning route and does not leave a blank navigator
- [x] 2.2 Add an assertion that tapping `Done` resets the controller state

## 3. Verification

- [x] 3.1 Run the focused exam results widget test file
- [x] 3.2 Run the full mobile test suite
- [x] 3.3 Install on `emulator-5554` and manually verify: complete an exam, tap `Done`, and confirm the learning screen is visible
