# Mobile Swipe Activity UI/UX Investigation

**Date:** 2026-05-09
**Mode:** Explore only, no application code changes

## Summary

The current mobile swipe implementation is mostly aligned with the canonical local-first learning-session spec for horizontal navigation and background refill. The visible card path reads from ObjectBox and does not await `/v1/learning/cards`; refill is separated into background inventory maintenance gated by `unstudied new words < 100`.

The production risks are not in the basic local-card lookup. They are in requirement drift, gesture execution hardening, and whether vertical gestures are supposed to count as study ratings.

## Normalized Production Gesture Map

| Gesture | Production intent | Current code path | Expected persistence |
|---|---|---|---|
| Right-to-left | Next mixed card with 15% new / 85% review target | `LearningSessionController.onSwipeRightToLeft()` -> `_showSelectedCard(mode: mixed)` | Local card selection only, then background refill check |
| Left-to-right | Review-first card with fallback to another available type | `LearningSessionController.onSwipeLeftToRight()` -> `_showSelectedCard(mode: reviewFirst)` | Local card selection only, then background refill check |
| Bottom-to-top | Remembered | `onSwipeBottomToTop()` -> `markRememberedLowFrequency()` -> `nextCard()` | Local word status becomes `mastered`, `nextReviewAt` moves about 10 days out |
| Top-to-bottom | Difficult | `onSwipeTopToBottom()` -> `markAsDifficultForRelearn()` -> `nextCard()` | Local word status becomes `learning`, `nextReviewAt` moves about 10 minutes out |

The current canonical spec supports this map:

| Evidence | Reference |
|---|---|
| Horizontal and vertical session rule, local-only card selection | `openspec/specs/mobile-learning-session/spec.md:4-17` |
| Card selection must not await network | `openspec/specs/mobile-learning-session/spec.md:23-29` |
| Rolling 20-card target is 3 new and 17 review | `openspec/specs/mobile-learning-session/spec.md:64-82` |
| Backend refill is only for inventory top-up, and only when unstudied new words are below 100 | `openspec/specs/mobile-local-cache-sync/spec.md:36-69` |

## Evidence From Current Code

| Area | Evidence | Reference |
|---|---|---|
| UI wiring | The screen passes controller methods directly into the gesture surface | `mobile/lib/src/ui/learning_screen.dart:97-102` |
| UI hint text | The on-screen hint says R-to-L is mixed, L-to-R is review-first, bottom-to-top is remembered, top-to-bottom is difficult | `mobile/lib/src/ui/learning_screen.dart:127-132` |
| Gesture recognizer | `GestureDetector.onPanEnd` chooses horizontal vs vertical and invokes the corresponding callback | `mobile/lib/src/ui/learning_screen.dart:306-334` |
| R-to-L controller behavior | R-to-L logs the gesture and selects `mode: mixed` | `mobile/lib/src/session/learning_session_controller.dart:131-139` |
| L-to-R controller behavior | L-to-R logs the gesture and selects `mode: reviewFirst` | `mobile/lib/src/session/learning_session_controller.dart:141-149` |
| Vertical remembered behavior | Bottom-to-top calls `markRememberedLowFrequency()` and advances | `mobile/lib/src/session/learning_session_controller.dart:151-179` |
| Vertical difficult behavior | Top-to-bottom calls `markAsDifficultForRelearn()` and advances | `mobile/lib/src/session/learning_session_controller.dart:181-208` |
| Local card selection | `_showSelectedCard()` chooses preferred kind and delegates to local repository lookup methods | `mobile/lib/src/session/learning_session_controller.dart:245-349` |
| Review fallback | Review-first tries review/difficult first, then falls back through the new-word lookup | `mobile/lib/src/session/learning_session_controller.dart:419-459` |
| Mixed target implementation | The selection window is 20 cards with `targetNewCards = 3` | `mobile/lib/src/session/card_selection.dart:3-13` |
| New-card local lookup | New lookup uses `nextNewWord()`, `randomNotMasteredWord()`, then `randomWord()` | `mobile/lib/src/data/word_repository.dart:214-278` |
| Review local lookup | Review lookup uses difficult/recent/due local words | `mobile/lib/src/data/word_repository.dart:290-328` |
| Background refill threshold | `topUpInventoryIfNeeded()` fetches only when unstudied count is below 100 | `mobile/lib/src/data/word_repository.dart:81-102` |
| Backend fetch isolation | `/v1/learning/cards` is only called from `refillLearningCards()` | `mobile/lib/src/data/word_repository.dart:353-385` |
| First-display transition | New words are marked `learning` before the refill check runs | `mobile/lib/src/session/learning_session_controller.dart:326-345` |

## Finding 1: Requirement Drift Is Real

There are conflicting OpenSpec statements around horizontal swipe meaning.

| Source | R-to-L meaning | L-to-R meaning |
|---|---|---|
| Current canonical spec | Next mixed card, 15% new / 85% review | Review-first selection with fallback |
| Current UI text | Next card, 15% new / 85% review | Review-first flow |
| Current controller | `_CardSelectionMode.mixed` | `_CardSelectionMode.reviewFirst` |
| Older completed proposal | Review-oriented weighting, 15% learned words | Review/new-mix flow with 15% new-word weighting |

The conflicting older proposal is at `openspec/changes/gesture-only-learning-and-daily-topup/proposal.md:7-15`. That artifact also says a daily refill check should fetch when unlearned local words drop below 100, while the current canonical local-cache spec says refill is a background path and the sole trigger is `countUnstudiedNewWords(language) < 100`.

Impact: a future implementer could follow the older completed proposal and reverse the horizontal semantics that the current spec, UI, and code now agree on.

Recommendation: mark the older proposal as superseded or add a short note in the active follow-up change saying `openspec/specs/mobile-learning-session/spec.md` is canonical for gesture direction semantics.

## Finding 2: Gesture Dispatch Is Not Hardened Against Async Races

`LearningCardGestureSurface` declares each gesture callback as `Future<void> Function()` but invokes the callbacks without awaiting or catching errors.

| Evidence | Reference |
|---|---|
| Callback fields are async futures | `mobile/lib/src/ui/learning_screen.dart:288-293` |
| Callbacks are invoked without `await`, `unawaited`, catch, or a local in-flight guard | `mobile/lib/src/ui/learning_screen.dart:323-332` |
| The UI only disables gestures via `isEnabled: !controller.isLoading` | `mobile/lib/src/ui/learning_screen.dart:97-99` |
| `isLoading` is set inside `_showSelectedCard()`, not at gesture recognition time | `mobile/lib/src/session/learning_session_controller.dart:245-256` |
| R-to-L and L-to-R await logging before entering `_showSelectedCard()` | `mobile/lib/src/session/learning_session_controller.dart:131-149` |
| Vertical gestures await repository work before calling `nextCard()` | `mobile/lib/src/session/learning_session_controller.dart:151-208` |

Why this matters for UX:

```text
pan ends
  -> gesture surface calls async callback and returns immediately
  -> controller may await logging or local writes before isLoading=true
  -> user can swipe again while the surface still appears enabled
  -> duplicate gesture callbacks can operate on the same currentWord
```

The existing controller has strong defenses once `_showSelectedCard()` starts, including a watchdog and `finally` reset. That does not fully cover the gap before `_showSelectedCard()` begins, especially for vertical gestures that mutate the current word before navigation.

Recommendation for a future implementation change: add a local gesture in-flight guard in `LearningCardGestureSurface` or make the controller set a pending gesture state synchronously before any awaited logging/local-write work. Also catch async callback errors so gesture failures are logged rather than becoming zone-level uncaught futures.

## Finding 3: Vertical Gestures Bypass Study Events And Proficiency Updates

The current gesture-only UI suggests bottom-to-top and top-to-bottom are the primary remembered/difficult actions. Those actions do not call the existing rating pipeline.

| Path | What happens | Reference |
|---|---|---|
| Vertical remembered | Calls `repository.markRememberedLowFrequency()` | `mobile/lib/src/session/learning_session_controller.dart:151-179` |
| Vertical difficult | Calls `repository.markAsDifficultForRelearn()` | `mobile/lib/src/session/learning_session_controller.dart:181-208` |
| Remembered repository method | Updates local state and syncs cache inventory in background | `mobile/lib/src/data/word_repository.dart:461-481` |
| Difficult repository method | Updates local state and syncs cache inventory in background | `mobile/lib/src/data/word_repository.dart:483-502` |
| Remembered DB mutation | Sets status to `mastered`, updates last-seen, schedules about 10 days out | `mobile/lib/src/data/local_database.dart:445-466` |
| Difficult DB mutation | Sets status to `learning`, updates last-seen, schedules about 10 minutes out | `mobile/lib/src/data/local_database.dart:468-487` |
| Rating pipeline | Inserts a `StudyEvent`, updates scheduling, submits to backend, applies returned proficiency | `mobile/lib/src/data/word_repository.dart:387-459` |
| Controller rating entrypoint | `rateCurrent()` is the only controller path that calls `recordRating()` | `mobile/lib/src/session/learning_session_controller.dart:501-544` |

This can be valid if remembered/difficult swipes are intentionally local-only state hints rather than ratings. It is a production bug if these swipes are the intended replacement for button-based ratings, because then the main learning activity path does not create study events and does not update `proficiency.scale`, `proficiency.level`, or `proficiency.level_index`.

Impact if vertical gestures are ratings:

| Missing behavior | User-visible or product impact |
|---|---|
| No `StudyEvent` inserted | Offline sync queue misses the user's primary study actions |
| No `submitStudyEvent()` call | Backend learner state and analytics miss remembered/difficult outcomes |
| No returned proficiency applied | Top-right proficiency label may stay stale after gesture-only study |
| No `TelemetryEvent.studyRatingSubmitted` | Product metrics undercount real study activity |

Recommendation: decide explicitly whether vertical swipes are local state controls or rating submissions. If they are ratings, the next change should route them through a study-event-producing path while preserving the local remembered/difficult scheduling semantics.

## Test Coverage Assessment

Focused tests passed:

```text
cd mobile && flutter test test/learning_screen_test.dart test/learning_session_controller_test.dart
Result: All tests passed
```

What the focused tests prove:

| Coverage | Reference |
|---|---|
| Horizontal gestures call the expected callbacks | `mobile/test/learning_screen_test.dart:172-199` |
| Vertical gestures call the expected callbacks | `mobile/test/learning_screen_test.dart:201-228` |
| New-word swipes show distinct local words | `mobile/test/learning_session_controller_test.dart:212-245` |
| Initial load does not wait for proficiency fetch | `mobile/test/learning_session_controller_test.dart:247-268` |
| Remembered swipe advances without waiting for cache sync | `mobile/test/learning_session_controller_test.dart:270-299` |
| Threshold does not fetch at 100 unstudied words | `mobile/test/learning_session_controller_test.dart:386-403` |
| Threshold fetches at 99 unstudied words | `mobile/test/learning_session_controller_test.dart:405-422` |
| Total pool size no longer independently triggers fetch | `mobile/test/learning_session_controller_test.dart:424-444` |
| Refill sequencing happens after `markWordAsLearning()` | `mobile/test/learning_session_controller_test.dart:446-470` |

Coverage gaps that matter for production UX:

| Gap | Risk |
|---|---|
| No UI-to-controller-to-DB integration test for vertical gestures | Callback routing can pass while persistence semantics are wrong |
| No rapid multi-swipe/debounce test | Duplicate async gestures can slip in before `isLoading` becomes true |
| No test for async callback failure from `LearningCardGestureSurface` | Future errors may be uncaught rather than handled as recoverable gesture failures |
| No test asserting vertical gestures create or intentionally do not create study events | The product decision around ratings vs local state remains ambiguous |
| No test asserting proficiency updates after gesture-only study | A stale proficiency label could ship undetected |

## Conclusion

The local-first word-loading requirement is currently satisfied in the visible card path. The swipe UI is directionally consistent with the current canonical spec, not with the older completed proposal.

The next OpenSpec follow-up should focus on two decisions:

| Decision | Why it is blocking |
|---|---|
| Supersede old horizontal gesture wording | Prevents future direction reversal |
| Define whether vertical swipes are ratings | Determines whether to preserve current local-only behavior or integrate study-event/proficiency updates |

If implementation resumes after exploration, the smallest production-hardening change would be gesture debouncing/error handling plus explicit vertical-study-event coverage.
