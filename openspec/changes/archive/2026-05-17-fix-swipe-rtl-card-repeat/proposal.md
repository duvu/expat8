## Why

After 3 new cards are swiped right-to-left, the session freezes on the same card repeating indefinitely. Two defects in the local card-selection layer cause this: `markWordLearned` never advances `nextReviewAtMs`, so `recentlyLearnedReviewWord` always returns the just-learned word as the top review candidate; and `markWordAsLearning` is fire-and-forget on card display, so a quick swipe can race with the status write and re-select the same new-word card.

## What Changes

- `markWordLearned` (local_database.dart): write `nextReviewAtMs = max(existing ?? 0, now + 30 min)` so the freshly learned word is not immediately due for review
- `recentlyLearnedReviewWord` (local_database.dart): add `nextReviewAtMs IS NULL OR nextReviewAtMs <= now` filter to match `nextDueReviewWord` semantics and exclude not-yet-due words
- `onSwipeRightToLeft` in `LearningSessionController` (learning_session_controller.dart): `await markWordAsLearning(word, now)` before `nextCard()` when `currentCardKind == CardKind.newWord` to close the fire-and-forget race; second call is idempotent

## Capabilities

### New Capabilities

- `mobile-local-card-dedup`: Mobile local SRS layer must not re-surface a word in the same session immediately after it has been learned; `nextReviewAtMs` is the scheduling gate for review re-selection.

### Modified Capabilities

_(none — no existing spec-level requirements change)_

## Impact

- `mobile/lib/src/data/local_database.dart`: two query/write methods
- `mobile/lib/src/session/learning_session_controller.dart`: one method body change
- No backend changes, no API contract changes, no ObjectBox schema changes
- Existing Flutter unit tests cover the affected methods; a targeted regression test should be added
