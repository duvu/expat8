## Context

The mobile app already uses local-first learning flows for vocabulary and workplace sentences, but the swipe semantics are not consistently framed as one shared interaction model and there is no learner-facing history replay or progress summary. The change must keep study offline-capable and avoid introducing backend contract changes.

## Goals / Non-Goals

**Goals:**
- Make swipe behavior consistent across all learning screens, including vocabulary and workplace sentence flows.
- Add an ordered history replay surface for items learned via right-to-left swipes.
- Add a stats page that shows learned, remembered, and difficult totals derived from local state.
- Keep the learning experience local-first and avoid new backend round-trips during swipe, history, or stats interactions.

**Non-Goals:**
- No new backend endpoints or server-side aggregation.
- No change to FITB rendering behavior.
- No change to vocabulary or sentence generation pipelines.
- No social/sharing features or cross-device sync for history/stats in this change.

## Decisions

- Use one shared local learning action model for vocabulary and sentence screens, so gesture semantics do not drift between flows.
  - Alternative considered: per-screen gesture rules. Rejected because it would fragment behavior and make the interaction model harder to learn and test.
- Treat right-to-left swipes as the only action that appends to the learned history trail and advances to the next card using the existing 15% new / 85% re-learned selection policy.
  - Alternative considered: use right-to-left as a generic next-card action without a history log. Rejected because the left-to-right replay requirement needs ordered history data.
- Route left-to-right swipes to a dedicated history view rather than another card-selection path.
  - Alternative considered: left-to-right as review mix navigation. Rejected because it conflicts with the requested "view history in order" behavior.
- Derive stats from local current-state data, not from the append-only history trail alone.
  - Alternative considered: count events only. Rejected because the requested totals are state-based and should reflect remembered/difficult/learned status, not just action frequency.
- Keep the history view read-only and the stats page read-only.
  - Alternative considered: allow edits from history/stats. Rejected because it would conflate navigation with state mutation.
- Reuse the existing local storage layer as source of truth.
  - Alternative considered: add backend reporting first. Rejected because this is primarily an interaction/UX correction and the app must remain local-first.

## Risks / Trade-offs

- [History log growth] → Keep the history as an append-only local trail and compact or cap presentation later if needed.
- [State vs event confusion] → Define history from the ordered action trail and stats from current local state so each surface has one clear source of truth.
- [Cross-screen inconsistency] → Centralize gesture mapping in shared code and cover both vocabulary and sentence screens with tests.
- [Migration complexity] → Add local storage fields/additions compatibly and backfill counts from existing learning records on first launch after upgrade.

## Migration Plan

- Add local persistence for ordered learning history and summary counters.
- Backfill initial counts from existing local learning records when the app first starts after the upgrade.
- Wire vocabulary and workplace sentence screens to the shared gesture/history/stats model without changing backend APIs.
- Roll back by reverting the app build; the local additions are additive and should leave existing records readable.
- No backend migration is required.

## Open Questions

- None blocking. If history pagination or content-type filters are desired later, they can be added as follow-up UX refinements.
