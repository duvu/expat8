## Why

The mobile app currently fetches new words from the server whenever the local pool is below a total-size target, even when hundreds of unstudied words already exist locally — this unnecessary network activity violates the offline-first principle and can stall card display if the fetch is slow. The fix aligns card selection and refill into two fully independent loops with a single clear trigger: fetch only when `unstudied < 100`.

## What Changes

- **Card selection is enforced local-only**: `showNewWord()` and all swipe handlers must never await or invoke any server call. Only `LocalDatabase.*` methods are allowed in the selection path.
- **Refill trigger simplified to one condition**: Replace the current composite check (total pool size, `vocabPoolFullSize`, rotation threshold) with `countUnstudiedNewWords(language) < 100`.
- **Startup refill respects the threshold**: After seeding the bundle, startup runs the same `< 100` check instead of always fetching because total is below `vocabPoolFullSize`.
- **Threshold check sequenced after `markWordAsLearning`**: When a new word is shown, the threshold check runs after the local state transition (new → learning) so the count is accurate before deciding to fetch.
- **Periodic timers only check the threshold**: Existing hourly/periodic timers continue to exist but only invoke the threshold check — they do not create an independent reason to fetch.

## Capabilities

### New Capabilities

*(none — this change tightens existing behavior rather than introducing a new user-facing feature)*

### Modified Capabilities

- `mobile-local-cache-sync`: Refill trigger condition changes from composite pool-size logic to strictly `unstudied < 100`; threshold check is sequenced after `markWordAsLearning` for new-word cards
- `mobile-learning-session`: Enforces that card selection never crosses the network; removes any implicit server dependency from the selection path

## Impact

- `mobile/lib/src/data/word_repository.dart` — `topUpInventoryIfNeeded()` refill condition simplified
- `mobile/lib/src/session/learning_session_controller.dart` — refill trigger moved to after `markWordAsLearning` callback
- `mobile/lib/main.dart` — startup refill check uses new threshold condition
- `mobile/test/learning_session_controller_test.dart` — test coverage for the boundary at 99 / 100
- No backend changes required
