## 1. Gesture Dispatch Hardening

- [x] 1.1 Add a single-flight guard to `LearningCardGestureSurface` that starts before invoking a recognized gesture callback.
- [x] 1.2 Ignore additional pan-end gestures while a gesture callback is in progress.
- [x] 1.3 Catch gesture callback failures and always clear the guard in `finally` so later gestures can run.
- [x] 1.4 Add widget tests for rapid duplicate gestures and failing async gesture callbacks.

## 2. Vertical Swipe Study Events

- [x] 2.1 Refactor study-event creation/submission into a reusable repository path that can be used by gesture actions without duplicating `recordRating()` logic.
- [x] 2.2 Map bottom-to-top remembered swipes to local `too_easy` study events while preserving remembered low-frequency local scheduling.
- [x] 2.3 Map top-to-bottom difficult swipes to local `too_hard` study events while preserving difficult relearn local scheduling.
- [x] 2.4 Ensure vertical swipe handling writes the local study event and word transition before advancing to the next local card.
- [x] 2.5 Ensure backend study-event submission or sync runs in the background and does not block local card advancement.

## 3. Proficiency And Session State

- [x] 3.1 Apply returned proficiency updates from gesture-submitted study-event sync when they match the active learning session.
- [x] 3.2 Reuse existing level-change feedback behavior for proficiency updates caused by vertical gesture study events.
- [x] 3.3 Ensure failed sync leaves the study event queued for retry and keeps the visible session usable.

## 4. Regression Coverage

- [x] 4.1 Add controller/repository tests that bottom-to-top creates a `too_easy` event, marks the word remembered/mastered, queues or syncs the event, and advances locally.
- [x] 4.2 Add controller/repository tests that top-to-bottom creates a `too_hard` event, marks the word difficult/learning, queues or syncs the event, and advances locally.
- [x] 4.3 Add tests that returned proficiency from gesture study-event sync updates the displayed session proficiency state.
- [x] 4.4 Add tests that offline or timed-out study-event sync does not block the next local card.

## 5. Verification

- [x] 5.1 Run focused mobile tests for learning screen, session controller, and word repository.
- [x] 5.2 Run `cd mobile && flutter test`.
- [x] 5.3 Confirm OpenSpec status shows the change apply-ready.
