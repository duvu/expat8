## 1. Convert ExamResultsScreen to StatefulWidget with reactive controller binding

- [x] 1.1 Convert `ExamResultsScreen` from `StatelessWidget` to `StatefulWidget` (rename inner class to `_ExamResultsScreenState`)
- [x] 1.2 Add `bool _timedOut = false` state field to `_ExamResultsScreenState`
- [x] 1.3 Add `Timer? _timeoutTimer` field; start a 20-second timer in `initState` that sets `_timedOut = true` and calls `setState` if `controller.result` is still null
- [x] 1.4 Cancel `_timeoutTimer` in `dispose` to avoid setState-after-dispose errors
- [x] 1.5 Wrap the `build` body in `ListenableBuilder(listenable: widget.controller, builder: (context, _) { ... })` so the widget rebuilds on every controller notification

## 2. Implement error and timeout UI inside the results screen

- [x] 2.1 Inside the `ListenableBuilder` builder, check states in priority order:
  1. `controller.result != null` → existing results UI (score, pass/fail, buttons) — no change
  2. `_timedOut` → timeout error UI
  3. `controller.state == ExamState.active && controller.errorMessage != null` → submission failure error UI
  4. otherwise → `CircularProgressIndicator` (genuinely waiting)
- [x] 2.2 Implement `_onRetry()` method: cancel timer, call `widget.controller.reset()`, then `Navigator.of(context).pop()`
- [x] 2.3 Create a shared `_buildErrorUI(String message)` helper that renders a centred `Column` with: error icon, error message text, and an outlined "Try Again" button wired to `_onRetry()`
- [x] 2.4 Use `_buildErrorUI('Exam submission timed out. Please try again.')` for the timeout case
- [x] 2.5 Use `_buildErrorUI(widget.controller.errorMessage!)` for the submission failure case

## 3. Cancel timeout timer on result arrival

- [x] 3.1 Inside the `ListenableBuilder` builder callback, if `controller.result != null` and `_timeoutTimer?.isActive == true`, call `_timeoutTimer!.cancel()` before rendering the results UI — prevents unnecessary `setState` after success

## 4. Tests

- [x] 4.1 Write a widget test: push `ExamResultsScreen` with `controller.result == null` and `state == submitting`, then set result and call `notifyListeners()` — assert results UI appears without hot-reload
- [x] 4.2 Write a widget test: push `ExamResultsScreen` with `controller.result == null`, advance fake clock by 21 seconds (using `fake_async`) — assert timeout error UI is shown
- [x] 4.3 Write a widget test: push `ExamResultsScreen` with `controller.result == null` and `state == active` plus a non-null `errorMessage` — assert error message and "Try Again" button are shown
- [x] 4.4 Write a widget test: tap "Try Again" — assert `controller.reset()` is called and `Navigator.pop` is triggered
- [x] 4.5 Run `cd mobile && flutter test` — confirm all tests pass

## 5. Verification

- [x] 5.1 Build and install APK on emulator: `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release --dart-define BACKEND_BASE_URL=https://expat8.x51.vn --dart-define SPEAKING_FOUNDATION_ENABLED=true`
- [ ] 5.2 Complete a full 5-question exam on the emulator — confirm results screen appears immediately after "See Results" is tapped
- [ ] 5.3 Confirm "Try Again" from results error state navigates back to the exam topic screen without crash
