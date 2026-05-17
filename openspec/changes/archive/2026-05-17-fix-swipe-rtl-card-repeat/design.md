## Context

The mobile learning session selects cards from a local ObjectBox database via `CardSelectionWindow` (window=20, targetNewCards=3). After 3 new cards are consumed, `preferredKind()` switches to `review`, which calls `recentlyLearnedReviewWord`. This query sorts by `lastSeenAtMs DESC` with no schedule gate — so the word just learned (whose `lastSeenAtMs` was just written by `markWordLearned`) is always returned first, creating an infinite repeat loop.

A secondary race: when a card is first displayed, `markWordAsLearning` is called fire-and-forget in `_showSelectedCard` so the in-progress status survives app-close. If the user swipes right-to-left before the ObjectBox write completes, `nextNewWord` still sees `status = newWord` and returns the same card.

Both bugs are confined to `local_database.dart` and `learning_session_controller.dart`. No backend, API, or ObjectBox schema changes are needed.

## Goals / Non-Goals

**Goals:**
- Ensure a word just processed by right-to-left swipe is not re-selected in the current session
- Close the fire-and-forget race for new-word cards
- Keep the fix minimal and localized — no structural refactoring

**Non-Goals:**
- Reworking the full SRS scheduling algorithm
- Changing how `nextDueReviewWord` works (it already filters correctly)
- Modifying backend card-selection logic
- Altering ObjectBox schema (no new fields needed; `nextReviewAtMs` already exists)

## Decisions

### Decision 1: Advance `nextReviewAtMs` in `markWordLearned` rather than filtering in the query only

**Chosen:** Write `nextReviewAtMs = max(existing ?? 0, now + 30 min)` inside `markWordLearned`.

**Rationale:** Filters in `recentlyLearnedReviewWord` would fix the immediate symptom, but `nextReviewAtMs = null` on a learned word is semantically wrong — it implies "never reviewed, due immediately." Advancing the field makes the stored state correct and consistent with `nextDueReviewWord`. 30 minutes is small enough not to disrupt any real SRS interval (minimum SRS interval is hours) but large enough to skip the entire current session.

**Alternative considered:** Filter-only in query without touching `markWordLearned`. Rejected: leaves a stale null/past `nextReviewAtMs` that could re-surface the word as soon as filtering is relaxed or another query path is added.

### Decision 2: Add `nextReviewAtMs IS NULL OR nextReviewAtMs <= now` to `recentlyLearnedReviewWord`

**Chosen:** Mirror the filter already present in `nextDueReviewWord`.

**Rationale:** Both methods pull review candidates — they should share the same scheduling gate. The asymmetry was the direct bug; aligning them makes the two code paths coherent and prevents a recurrence if the write in Decision 1 is ever missed.

### Decision 3: Await `markWordAsLearning` in `onSwipeRightToLeft` for new-word cards

**Chosen:** Change the fire-and-forget call to `await markWordAsLearning(word, now)` before calling `nextCard()`, only in the swipe handler (not in `_showSelectedCard`).

**Rationale:** `_showSelectedCard` keeps the fire-and-forget call for crash resilience (status survives if app is killed mid-swipe). The swipe handler, however, controls the transition — it is the correct place to guarantee the write is committed before card selection runs. The call is idempotent so double-calling is safe.

**Alternative considered:** Remove fire-and-forget from `_showSelectedCard` entirely and only call in the swipe handler. Rejected: loses crash resilience — if the user swipes and the app crashes before the swipe handler completes, the word reverts to `newWord` status.

## Risks / Trade-offs

- **30-minute floor on `nextReviewAtMs`** → If a user somehow exits and re-enters the session within 30 minutes, the just-learned word will not appear as a review card. This is the desired behavior and aligns with SRS design (minimum meaningful review gap is much longer).
- **Idempotency of `markWordAsLearning`** → The implementation must confirm the call is truly idempotent (it sets `status = learning` if `status == newWord`). If not, a double-call could corrupt state. Verify in code before relying on this.
- **Test coverage gap** → The repeat-card scenario is not currently covered by unit tests. A targeted test should be added as part of this change to prevent regression.

## Migration Plan

No data migration needed. `nextReviewAtMs` already exists on `LocalWordEntity`; existing rows with `null` are treated as "due immediately" today, which is consistent with the new filter (`IS NULL OR <= now` still returns them as candidates if they were not just learned). The fix only affects rows that go through `markWordLearned` after the update is deployed — existing null rows are unaffected until the user next swipes them.

Rollback: revert the three code changes; no DB cleanup needed.

## Open Questions

_(none)_
