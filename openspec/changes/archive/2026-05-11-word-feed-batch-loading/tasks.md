## 1. Backend — Fix /v1/learning/cards to always return limit words

- [x] 1.1 Locate the `POST /v1/learning/cards` route handler and identify where word selection terminates early when stored words are insufficient.
- [x] 1.2 After selecting stored eligible words, compute `shortfall = limit − storedCount`. If shortfall > 0, call the AI generation pipeline to generate `shortfall` additional words.
- [x] 1.3 Merge stored words and newly generated words into a single response array of exactly `limit` items (or however many were produced if generation partially failed).
- [x] 1.4 Update `actual_mix.new` in the response to reflect the real number of words returned.
- [x] 1.5 Write a backend unit/integration test asserting that a request with an empty word pool returns 10 words (triggers generation).

## 2. Mobile — Initial batch load before learning screen

- [x] 2.1 In `WordRepository`, add a `prefetchBatch({int batchSize = 10})` method that calls `BackendApiClient.fetchCards(limit: batchSize)` and persists results via `LocalDatabase.addBatch()`.
- [x] 2.2 In `LocalDatabase`, add `addBatch(List<VocabularyWord> words)` that enforces the cap: if `localWordCount >= 990`, call `pruneToMostRecent(990)` before inserting.
- [x] 2.3 In `main.dart` (or app initializer), after opening the database, call `wordRepository.prefetchBatch()` if local unlearned count < 10, and await it before navigating to the learning screen.
- [x] 2.4 Show a loading indicator (e.g., `CircularProgressIndicator`) while the initial prefetch is in flight.

## 3. Mobile — Low-watermark background prefetch

- [x] 3.1 In `LearningSessionController`, add a `_prefetchInFlight` boolean flag (default `false`).
- [x] 3.2 After each card advance, check if `localUnlearnedCount <= 3`. If true and `!_prefetchInFlight`, set `_prefetchInFlight = true`, call `wordRepository.prefetchBatch()` in the background, and reset the flag on completion.
- [x] 3.3 Ensure the low-watermark check does not block the UI thread — use `unawaited()` or a background isolate pattern.
- [x] 3.4 Write a unit test asserting that `_prefetchInFlight` debounces concurrent triggers.

## 4. Mobile — Cap enforcement on batch insert

- [x] 4.1 Verify `LocalDatabase.pruneToMostRecent(maxCount)` skips words with pending sync queue entries (confirm existing ObjectBox query logic).
- [x] 4.2 Add test: insert 995 words into a test database, call `addBatch(10 words)`, verify total count is ≤ 1000 and the 5 oldest pruneable words were removed.
- [x] 4.3 Add test: insert 5 words, call `addBatch(10 words)`, verify no pruning occurs and total count is 15.

## 5. Tests and QA

- [x] 5.1 Run full mobile test suite (`flutter test`) and fix any regressions.
- [x] 5.2 Run backend tests (`npm test`) and fix any regressions.
- [x] 5.3 Manual QA: launch on emulator, verify initial 10-word batch loads, advance through cards to trigger low-watermark refetch, verify no duplicate words appear.
