## Context

The mobile learning screen is gesture-only: right-to-left requests the next mixed card, left-to-right requests review-first selection, bottom-to-top marks remembered, and top-to-bottom marks difficult. The visible card path is already local-first and background refill is already gated by `countUnstudiedNewWords(language) < 100`.

The remaining risks are in the interaction boundary. `LearningCardGestureSurface` invokes async gesture callbacks without awaiting, catching, or debouncing them, so rapid swipes can overlap before `isLoading` becomes true. Vertical swipes also mutate local word state through remembered/difficult helpers but do not create study events or apply returned proficiency changes, even though those swipes are the only visible study actions in the gesture-only UI.

## Goals / Non-Goals

**Goals:**
- Preserve the canonical horizontal gesture mapping from `mobile-learning-session`: right-to-left is mixed, left-to-right is review-first.
- Make gesture dispatch single-flight so rapid or failing async callbacks cannot duplicate study mutations or leave uncaught future errors.
- Treat vertical remembered/difficult swipes as study actions that persist local study events before background sync.
- Preserve existing local remembered/difficult scheduling semantics: remembered becomes low-frequency/mastered, difficult enters relearn quickly.
- Apply proficiency updates returned by immediate or deferred sync without blocking local card advancement.
- Add focused tests that prove the UI, controller, local DB, sync queue, and proficiency behavior.

**Non-Goals:**
- Changing backend study-event endpoints or rating enum values.
- Changing the 15% new / 85% review rolling-window target.
- Changing local-first card selection or adding server calls to the visible swipe path.
- Adding undo support for accidental swipes.
- Reworking ObjectBox entity shape unless implementation proves it is unavoidable.

## Decisions

### D1: Canonical horizontal gestures remain unchanged

Right-to-left SHALL continue to call the mixed selector, and left-to-right SHALL continue to call the review-first selector. The older `gesture-only-learning-and-daily-topup` proposal text is treated as superseded where it conflicts with `openspec/specs/mobile-learning-session/spec.md`.

Rationale: the current spec, UI hint text, and controller behavior already agree on this mapping. Reversing it would introduce a user-visible regression.

Alternative considered: follow the older proposal wording and reverse left/right semantics. Rejected because it conflicts with the current canonical spec and implemented behavior.

### D2: The gesture surface owns single-flight dispatch

Add a local gesture in-flight guard inside `LearningCardGestureSurface`. On a recognized gesture, set the guard before invoking the async callback, ignore additional gestures while it is active, catch callback failures, and clear the guard in `finally` when the callback completes.

Rationale: `controller.isLoading` is only set after the callback reaches card selection, and vertical gestures do local writes before advancing. The UI boundary is the earliest reliable place to prevent duplicate gesture dispatch.

Alternative considered: rely only on controller `isLoading`. Rejected because the investigation found an async gap before `isLoading` becomes true.

### D3: Vertical swipes become study-event-producing actions

Create or refactor a repository/controller path that records a gesture study event locally, applies the gesture-specific local word transition, schedules sync, and advances to the next local card. Suggested rating mapping:

| Gesture | Study rating | Local transition |
|---|---|---|
| Bottom-to-top remembered | `too_easy` | Mark mastered/remembered with low relearn frequency |
| Top-to-bottom difficult | `too_hard` | Mark learning/difficult with short relearn interval |

Rationale: `too_easy` and `too_hard` match the existing backend rating semantics for strong positive/negative learning signals, while the local transition preserves the product-specific remembered/difficult scheduling already implemented.

Alternative considered: keep vertical swipes as local-only hints. Rejected because gesture-only UI would then omit study events, backend learner state, proficiency updates, and analytics for the primary study actions.

### D4: Backend sync and proficiency update are background-safe

Vertical swipe handling should not wait on network before showing the next card. The local event and local word transition happen first; the app may attempt immediate submit/sync in the background. If backend returns proficiency, the controller applies it and emits the existing level-change feedback. If sync fails, the event remains queued for retry.

Rationale: this preserves offline-first UX and keeps `/v1/study-events` outside the visible card-selection critical path while still converging learner state.

Alternative considered: call the existing `rateCurrent()` path directly from vertical gestures. Rejected unless refactored, because the existing path awaits `recordRating()` and its current local scheduling does not exactly match remembered/difficult gesture semantics.

### D5: Tests should cover behavior, not only callback counts

Add widget tests for single-flight gesture dispatch and callback error handling, plus controller/repository tests that assert vertical swipes insert study events, queue sync on failure, preserve local scheduling, advance locally, and apply returned proficiency when available.

Rationale: current tests prove callback routing and threshold refill behavior, but they do not prove the production persistence semantics of vertical swipe activity.

Alternative considered: only add unit tests around repository helpers. Rejected because the highest-risk gap is the UI-to-controller async boundary.

## Risks / Trade-offs

- [Risk] Mapping remembered to `too_easy` and difficult to `too_hard` changes proficiency behavior for vertical swipes. -> Mitigation: document the mapping in specs and cover level-change behavior in tests.
- [Risk] Gesture single-flight guard could make the UI feel unresponsive if a callback hangs. -> Mitigation: keep controller watchdog behavior and avoid awaiting network in vertical swipe callbacks.
- [Risk] Refactoring rating persistence could duplicate study-event code paths. -> Mitigation: extract a shared helper for local event creation/submission rather than copying `recordRating()` logic.
- [Risk] Background proficiency updates can arrive after the user changes language or session state. -> Mitigation: apply returned proficiency only when it matches the active learning language/session context.

## Migration Plan

1. Implement the mobile-only changes behind the existing gesture UI with no backend API changes.
2. Run focused widget/controller/repository tests, then `cd mobile && flutter test`.
3. Build Android release only after tests pass.
4. Rollback by reverting the mobile change; no persisted data migration is required because new study events use existing local entities and backend contracts.

## Open Questions

- Should bottom-to-top remembered use `too_easy` or `easy` if product wants remembered to avoid level-up pressure? The design chooses `too_easy` because remembered is the strongest positive gesture.
- Should top-to-bottom difficult use `too_hard` or `hard`? The design chooses `too_hard` because difficult currently means relearn quickly, not normal review.
