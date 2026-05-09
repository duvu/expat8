## 1. Simplify refill trigger condition

- [x] 1.1 In `word_repository.dart`, replace the composite refill condition (`total == 0`, `total < vocabPoolFullSize`, `unstudied < vocabRotationUnstudiedThreshold`) with a single check: `countUnstudiedNewWords(activeLanguage) < 100`
- [x] 1.2 Remove or stop reading `vocabPoolFullSize` and `vocabRotationUnstudiedThreshold` config values from `AppConfig` if they are only used for the refill trigger (keep any values used for pruning logic)
- [x] 1.3 Verify `topUpInventoryIfNeeded()` has an in-flight guard to prevent concurrent fetches — add one if missing

## 2. Sequence refill check after markWordAsLearning

- [x] 2.1 In `learning_session_controller.dart`, locate where `showNewWord()` calls `markWordAsLearning` and `topUpInventoryIfNeeded`
- [x] 2.2 Move the `topUpInventoryIfNeeded()` call into the `.then()` callback of `markWordAsLearning()` so it only runs after the local state transition completes
- [x] 2.3 Confirm the card render path (`_showSelectedCard`) does not await any part of the refill chain

## 3. Fix startup top-up

- [x] 3.1 In `main.dart`, confirm `topUpInventoryIfNeeded()` is called after `seedFromBundleIfEmpty()` (no change needed if already the case)
- [x] 3.2 With the simplified condition in place (task 1.1), verify that a healthy seed (≥ 100 unstudied words) no longer triggers a startup fetch — trace through the new condition manually

## 4. Tests

- [x] 4.1 Add test: `countUnstudiedNewWords = 100` → `topUpInventoryIfNeeded` does NOT call `fetchLearningCards`
- [x] 4.2 Add test: `countUnstudiedNewWords = 99` → `topUpInventoryIfNeeded` DOES call `fetchLearningCards`
- [x] 4.3 Add test: `countUnstudiedNewWords = 200`, `totalWords = 200` (below old pool full size) → no fetch
- [x] 4.4 Add test: threshold check runs after `markWordAsLearning` completes, not before — assert call order
- [x] 4.5 Add test: backend timeout during refill → card selection still returns local word without throwing
- [x] 4.6 Confirm existing `showNewWord()` tests still pass with no modifications to their assertions
