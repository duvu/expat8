# Mobile Local-First Word Loading Exploration

**Date:** 2026-05-09
**Mode:** Explore only, no implementation

## Core Requirement

Mobile app must always select the next learning card from its local ObjectBox database. The act of showing a word must not depend on fetching more words from the server.

Server fetching is only a background refill mechanism. It may be triggered when the active language has fewer than 100 unstudied local words.

The simplest invariant:

```text
Card selection path: local DB only
Refill path: server allowed only when local unstudied count < 100
```

## Current Shape

The codebase is already close to the desired model.

Relevant files:

| Area | File | Current role |
|---|---|---|
| Card selection | `mobile/lib/src/session/learning_session_controller.dart` | Calls repository lookup methods and triggers background inventory top-up |
| Local word reads | `mobile/lib/src/data/word_repository.dart` | `getNewWordWithFallbackResult()` reads local DB only |
| Local DB queries | `mobile/lib/src/data/local_database.dart` | `nextNewWord()`, `randomNotMasteredWord()`, `randomWord()`, `countUnstudiedNewWords()` |
| Server refill | `mobile/lib/src/data/word_repository.dart` | `topUpInventoryIfNeeded()` and `refillLearningCards()` |
| API call | `mobile/lib/src/api/backend_api_client.dart` | `POST /v1/learning/cards` with `card_mode: "new"` |
| Startup | `mobile/lib/main.dart` | Seeds bundle vocabulary, syncs cache inventory, starts top-up |

Important existing behavior:

```text
showNewWord()
  -> _showSelectedCard()
    -> getNewWordWithFallbackResult()
      -> database.nextNewWord()
      -> database.randomNotMasteredWord()
      -> database.randomWord()
      -> no backend call here
```

That is good. The card-selection path is already local-first.

The mismatch is in the refill trigger. `topUpInventoryIfNeeded()` currently considers total local word count and pool fullness:

```text
if total == 0 -> refill
if total < vocabPoolFullSize -> refill
if unstudied < vocabRotationUnstudiedThreshold -> rotate/refill
```

This means the app can fetch from server even when it still has more than 100 unstudied local words. Example: after bundled seed inserts 200 unstudied words, total may still be below 1000, so startup top-up can fetch despite `unstudied = 200`.

That violates the new stricter rule.

## Desired Mental Model

Separate card delivery from inventory maintenance.

```text
┌─────────────────────────────────────────────────────────────┐
│                     USER WANTS A CARD                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ Local ObjectBox  │
                    │ only             │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
       ┌─────────────┐              ┌────────────────┐
       │ Show card   │              │ Local empty or │
       │ immediately │              │ fallback empty │
       └─────────────┘              └────────────────┘

No server call is allowed to decide the current card.
```

Inventory refill is a separate background loop:

```text
┌─────────────────────────────────────────────────────────────┐
│                  BACKGROUND INVENTORY CHECK                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              count status == newWord for active language
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
       ┌──────────────┐              ┌─────────────────┐
       │ count >= 100 │              │ count < 100     │
       │ do nothing   │              │ fetch in bg     │
       └──────────────┘              └────────┬────────┘
                                               │
                                               ▼
                                  POST /v1/learning/cards
                                  { card_mode: "new" }
                                               │
                                               ▼
                                  addBatch() into ObjectBox
                                               │
                                               ▼
                                  smart prune to <= 1000
```

## Proposed Rule Set

### R1: Card Selection Never Fetches

`showNewWord()`, `nextCard()`, and swipe handlers must never await or invoke server refill as part of selecting the current card.

Allowed during selection:

```text
LocalDatabase.nextNewWord()
LocalDatabase.randomNotMasteredWord()
LocalDatabase.randomWord()
LocalDatabase.nextDueReviewWord()
LocalDatabase.recentlyLearnedReviewWord()
```

Not allowed during selection:

```text
BackendApiClient.fetchLearningCards()
WordRepository.refillLearningCards()
Any await that depends on /v1/learning/cards
```

### R2: Refill Trigger Is Only `unstudied < 100`

The only business condition for fetching new words from server should be:

```text
database.countUnstudiedNewWords(language: activeLanguage) < 100
```

This replaces the current total-pool checks as a server-fetch condition.

Consequences:

| Local state | Should fetch? | Reason |
|---|---:|---|
| 0 unstudied | yes | `0 < 100`, but only background |
| 50 unstudied | yes | Low local buffer |
| 99 unstudied | yes | Strictly below 100 |
| 100 unstudied | no | User said below 100 |
| 200 unstudied, total 200 | no | Enough unstudied words despite pool not full |
| 900 unstudied, total 1000 | no | Enough unstudied words |

### R3: Startup Must Not Force Fetch When Seed Is Healthy

Startup can still seed from bundled vocabulary. After seeding, startup may run the same background threshold check.

```text
startup
  -> seedFromBundleIfEmpty()
  -> countUnstudiedNewWords(active language)
  -> if < 100: background refill
  -> else: no server refill
```

This avoids the current case where seed has 200 words but startup fetches anyway because total is below `vocabPoolFullSize`.

### R4: Refill Is Best-Effort and Non-Blocking

If refill fails, times out, returns 0 items, or cache inventory sync fails, the user-facing card path must continue using local words.

This means failures should be logged but not surfaced as card loading failure unless local DB itself has no usable word.

### R5: Active Language Scope

The threshold is per active learning language.

```text
English newWord count < 100 -> fetch English
Chinese newWord count >= 100 -> do not fetch Chinese
```

Switching language should run the same background threshold check for the new active language, still without blocking card selection.

### R6: Do Not Add Client Exclusion Lists

Backend duplicate avoidance is owned by learner state and `PUT /v1/user-word-cache`. Mobile refill should continue using `POST /v1/learning/cards` with `card_mode: "new"`, not client-side exclusion lists.

## The Subtle Race

There is a small race around `markWordAsLearning()`.

Current card flow marks a shown new word as `learning` asynchronously after the card is displayed. That is correct because a shown word is no longer unstudied.

But refill checks can run too early:

```text
unstudied = 100
show card
trigger top-up immediately sees 100 -> no fetch
markWordAsLearning completes -> unstudied = 99
no refill was triggered
```

The design should make the refill check happen after the local state transition when the selected card is a new word.

```text
show local card
  -> mark newWord as learning
    -> then run background threshold check
```

The UI still does not wait for server. It only waits, at most, for the local state transition if the code chooses to sequence it. Another option is to let `markWordAsLearning()` fire-and-forget but trigger threshold check from its completion callback.

## Suggested Target Flow

```text
_showSelectedCard()
  │
  ├─ select word from local DB
  │
  ├─ render word / empty state
  │
  └─ if selected newWord:
       └─ background:
            markWordAsLearning()
              └─ topUpInventoryIfNeeded()

topUpInventoryIfNeeded()
  │
  ├─ unstudied = countUnstudiedNewWords(activeLanguage)
  │
  ├─ if unstudied >= 100: return none
  │
  └─ if unstudied < 100:
       ├─ fetch new cards from backend
       ├─ addBatch()
       ├─ prune smartly to local cap
       └─ sync cache inventory best-effort
```

## What To Remove Conceptually

The following concepts should not decide whether to fetch from server:

```text
total local words == 0
total local words < vocabPoolFullSize
hourly top-up just because an hour passed
pool-full target without considering unstudied count
current card request needing a word immediately
```

Periodic timers are still fine, but they should only run the threshold check. They should not create an independent reason to fetch.

## What To Keep

Keep these existing ideas because they support the requirement:

| Existing behavior | Why keep it |
|---|---|
| `getNewWordWithFallbackResult()` reads local DB only | Core local-first invariant |
| Random non-mastered fallback | Prevents empty screen when new words are exhausted |
| Final random local fallback | Keeps app usable even in odd local states |
| Fire-and-forget top-up | Server is decoupled from UI latency |
| Smart prune to 1000 words | Keeps ObjectBox bounded without deleting useful new words first |
| `PUT /v1/user-word-cache` sync | Backend-owned duplicate avoidance |

## Potential Test Cases

Repository-level tests:

| Test | Expected result |
|---|---|
| 100 unstudied local words | no call to `fetchLearningCards()` |
| 101 unstudied local words | no call to `fetchLearningCards()` |
| 99 unstudied local words | calls `fetchLearningCards()` in refill path |
| 200 unstudied, total below pool full size | no call to `fetchLearningCards()` |
| 0 unstudied, backend timeout | returns `TopUpResult` with no loaded words, no throw to UI |
| language `zh` below threshold while `en` healthy | fetch only for active `zh` |

Controller-level tests:

| Test | Expected result |
|---|---|
| `showNewWord()` with local word and hanging backend | returns local word quickly |
| Empty local DB and backend has words | current call shows empty/local fallback, not fetched server word |
| Showing the 100th unstudied word | threshold check after local mark sees 99 and triggers refill |
| Repeated swipes below threshold | only one refill in flight |

API-client tests do not need major changes, because `fetchLearningCards()` still sends `card_mode: "new"`.

## Open Questions

### Q1: Does "load từ mới" mean only `newWord`, or any local card?

The existing product direction says the app should still show random non-mastered local words when no new words remain. The new sentence says "luôn luôn chỉ load từ mới trong local database".

Two possible readings:

| Interpretation | Behavior |
|---|---|
| Strict new-only | If no `newWord`, show empty state even if review/non-mastered words exist |
| Local-card first | Prefer `newWord`, then local fallback cards, never server for current card |

The current app and previous investigation docs favor the second interpretation.

### Q2: Should refill batch size be 100 or enough to restore to a larger buffer?

If threshold is `<100`, fetching exactly 100 at count 99 gives around 199 unstudied words. That seems healthy.

Fetching until local unstudied reaches 1000 would violate the spirit of "only fetch when below 100" less directly, but it may create larger payloads and more pruning. A simple 100-card batch is cleaner.

### Q3: Should first install depend on server if bundle seed is missing?

Strict answer: no. If local DB and bundle seed are empty, the app may trigger background refill because `0 < 100`, but the current card load must still not wait for it.

This creates a possible first-run empty state in pathological builds with no seed vocabulary. That is acceptable if the invariant is more important than immediate server-backed display.

## Crisp Design Statement

The app has two independent loops.

```text
Learning loop:
  user action -> local DB -> card now

Maintenance loop:
  background trigger -> count local newWord -> if <100 -> fetch server -> store locally
```

The learning loop must never cross into the network. The maintenance loop must never be required for the current card.

## Candidate Change Scope

If this becomes an OpenSpec change, likely affected capabilities:

| Capability | Change |
|---|---|
| `mobile-learning-session` | Card selection must be local-only and non-blocking |
| `mobile-local-cache-sync` | Server refill trigger becomes strictly `unstudied < 100` |
| `swipe-auto-prefetch` | Refine trigger sequencing after `newWord -> learning` transition |

Likely implementation files later, after leaving explore mode:

```text
mobile/lib/src/data/word_repository.dart
mobile/lib/src/session/learning_session_controller.dart
mobile/lib/main.dart
mobile/test/word_repository_test.dart
mobile/test/learning_session_controller_test.dart
```

No backend change appears necessary.
