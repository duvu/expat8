## Why

Mobile swipe learning is now the primary study interaction, but the current implementation still has production risks around async gesture races, stale requirement wording, and vertical gestures bypassing the study-event/proficiency pipeline. This change hardens the gesture surface and makes swipe-driven study activity durable, syncable, and aligned with the canonical local-first session contract.

## What Changes

- Treat the current `mobile-learning-session` spec as canonical for horizontal swipe semantics: right-to-left selects the next mixed card, and left-to-right selects review-first with fallback.
- Add gesture in-flight protection so rapid or failing async callbacks cannot trigger duplicate mutations or leave unhandled gesture futures.
- Define vertical swipes as study actions that record local study events before background sync while preserving the existing remembered/difficult local scheduling behavior.
- Apply returned proficiency updates after gesture-submitted study events so the session label remains current.
- Add focused mobile tests for gesture debounce/error handling, vertical swipe persistence, study-event creation, and proficiency updates.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mobile-learning-session`: Clarify canonical swipe semantics, require hardened async gesture dispatch, and require vertical swipe study actions to persist study events and proficiency updates without blocking local card advancement.

## Impact

- Mobile UI: `LearningCardGestureSurface` gesture dispatch and callback failure handling.
- Mobile session logic: vertical swipe routing, in-flight state, proficiency update handling, and card advancement sequencing.
- Mobile data layer: reuse or extend local study-event/rating persistence while preserving remembered/difficult scheduling semantics.
- Mobile tests: widget and controller coverage for rapid swipes, callback failures, vertical gesture persistence, sync queue behavior, and proficiency label updates.
- OpenSpec docs: supersede conflicting older horizontal gesture wording by anchoring implementation to `openspec/specs/mobile-learning-session/spec.md`.
