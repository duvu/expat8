## 1. Fix markWordLearned — advance nextReviewAtMs

- [x] 1.1 In `local_database.dart`, locate `markWordLearned` and read its current implementation
- [x] 1.2 After setting `lastSeenAtMs = now`, compute `newNextReview = max(existingNextReviewAtMs ?? 0, now + 30 * 60 * 1000)`
- [x] 1.3 Write `entity.nextReviewAtMs = newNextReview` and save the updated entity
- [x] 1.4 Confirm idempotency: calling `markWordLearned` twice advances to the same value (max wins)

## 2. Fix recentlyLearnedReviewWord — add scheduling gate

- [x] 2.1 In `local_database.dart`, locate `recentlyLearnedReviewWord` and read its current ObjectBox query
- [x] 2.2 Add condition: `nextReviewAtMs IS NULL OR nextReviewAtMs <= now` (mirror `nextDueReviewWord`)
- [x] 2.3 Verify the query still returns words with `nextReviewAtMs = null` (should remain eligible)
- [x] 2.4 Verify the query excludes words where `nextReviewAtMs > now`

## 3. Fix onSwipeRightToLeft — await markWordAsLearning for new-word cards

- [x] 3.1 In `learning_session_controller.dart`, locate `onSwipeRightToLeft`
- [x] 3.2 Find the branch where `currentCardKind == CardKind.newWord`
- [x] 3.3 Change the `markWordAsLearning(word, now)` call to `await markWordAsLearning(word, now)` before `nextCard()`
- [x] 3.4 Confirm `_showSelectedCard` still retains its fire-and-forget `markWordAsLearning` for crash resilience (do not remove it)

## 4. Tests

- [x] 4.1 Add a unit test in `local_database_test.dart` (or equivalent): after `markWordLearned`, `recentlyLearnedReviewWord` must NOT return the just-learned word
- [x] 4.2 Add a unit test: after `markWordLearned` twice, `nextReviewAtMs` equals `now + 30 min` (max semantics)
- [x] 4.3 Add a unit test: `recentlyLearnedReviewWord` returns a word with `nextReviewAtMs = null`
- [x] 4.4 Add a unit test: `recentlyLearnedReviewWord` excludes a word with `nextReviewAtMs = now + 1 hour`
- [x] 4.5 Run `flutter test` — all tests pass

## 5. Verify end-to-end

- [x] 5.1 Run the app on a device/emulator, swipe right-to-left through at least 5 cards — confirm no card repeats
- [x] 5.2 Confirm `nextDueReviewWord` and `recentlyLearnedReviewWord` are consistent (both respect the schedule gate)
- [x] 5.3 Verify that after 30+ minutes (or by manually setting `nextReviewAtMs` to a past time in a test), the word becomes eligible for review again
