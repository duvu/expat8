## Context

The mobile app has two paths that currently interact in a way that violates offline-first:

1. **Card selection path** (`_showSelectedCard` → `getNewWordWithFallbackResult` → `LocalDatabase.*`) — already correct: local-only, never touches the network.
2. **Refill path** (`topUpInventoryIfNeeded` → `refillLearningCards` → `POST /v1/learning/cards`) — currently triggers on multiple conditions: `total == 0`, `total < vocabPoolFullSize` (default 1000), `unstudied < vocabRotationUnstudiedThreshold`.

The bug: after the seed vocabulary is loaded (e.g., 200 English words), `total = 200` which is below `vocabPoolFullSize = 1000`, so startup top-up fetches from the server even though `unstudied = 200`. This unnecessary fetch can slow startup and violates the stated invariant.

A secondary issue: when a new card is shown, the refill threshold check can race with `markWordAsLearning`. If the check runs before the local state transition, it sees `unstudied = 100` and skips the fetch; after the transition it would see `unstudied = 99` and should fetch — but it already decided not to.

## Goals / Non-Goals

**Goals:**
- Single refill condition: `countUnstudiedNewWords(activeLanguage) < 100`
- Threshold check runs after `markWordAsLearning` completes for new-word cards
- Startup refill respects the same threshold after bundle seeding
- Card selection path remains network-free; all `LocalDatabase.*` calls allowed
- No changes to backend, API shape, or authentication

**Non-Goals:**
- Changing the card selection mix (15% new / 85% review) — separate concern
- Implementing a new refill batch size strategy — keep existing batch size
- Removing periodic timers — they stay, but only trigger the threshold check
- Handling multi-language simultaneous refill — threshold is checked per active language only

## Decisions

**Replace composite condition with single unstudied count**
The `vocabPoolFullSize` and total-word checks no longer gate server fetches. Only `countUnstudiedNewWords(language) < 100` does. This removes the case where a full seed (200 unstudied) still triggers a fetch because the "pool" target is 1000.

Alternative considered: keep `total == 0` as an additional trigger — rejected because `total == 0` is covered by the threshold (`0 < 100`), so it's redundant.

**Threshold check sequenced after `markWordAsLearning`**
When `showNewWord()` selects a new-word card, the flow is:
```
select card from local DB
render card immediately (no await)
background: markWordAsLearning() → then → topUpInventoryIfNeeded()
```
`topUpInventoryIfNeeded()` is called in the `.then()` callback of `markWordAsLearning()`, not concurrently. This ensures the count is decremented before the threshold is evaluated.

Alternative: fire both concurrently — rejected because it reintroduces the race at exactly the boundary (99/100) that matters most.

**Periodic timers delegate to the same threshold function**
The existing periodic worker that runs every hour (or similar interval) simply calls `topUpInventoryIfNeeded()`. No change to the timer itself — only the condition inside changes.

**Startup top-up uses the same function**
`main.dart` already calls `topUpInventoryIfNeeded()` after seeding. With the simplified condition, this call becomes correct by default: if seeding put 200 unstudied words in, `200 < 100` is false and no fetch occurs.

## Risks / Trade-offs

- **Boundary at exactly 100** — if a user has exactly 100 unstudied words and studies one, the count drops to 99 and a refill is triggered. The fetch adds ~100 words, bringing the count back to ~199. This is acceptable churn.
- **Single active language** — the threshold is only checked for the active learning language. If the user switches languages, the threshold is checked for the new language at that point. Words in other languages are unaffected.
- **Refill fires on every new-word card at the boundary** — at exactly 99 unstudied, every new-word swipe triggers a refill attempt. The existing debounce/in-flight guard in `topUpInventoryIfNeeded` prevents concurrent fetches; this is already correct behavior.

## Migration Plan

No data migration. The change is a condition simplification in Dart source code. Existing ObjectBox data is unaffected. Deployed immediately on next app build.
