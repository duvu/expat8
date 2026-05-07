## Context

The `POST /v1/learning/cards` endpoint is the sole word-feed API for the mobile app. Currently it can return zero words if the backend word pool is empty, because it does not trigger AI generation as a fallback. On the mobile side, the app fetches one word at a time on demand, has no prefetch buffer, and does not proactively enforce the 1000-word cap except when `pruneToMostRecent` is called manually.

The result: users see a blank learning screen on first launch and stale content after the local cache drains.

## Goals / Non-Goals

**Goals:**
- Backend: `POST /v1/learning/cards` always returns exactly `limit` words, using AI generation to fill gaps.
- Mobile: Load an initial batch of 10 words before showing the learning screen.
- Mobile: Trigger a background refetch when the unlearned local queue drops to ≤ 3 words.
- Mobile: Enforce the 1000-word local cap on every batch insertion (prune oldest 10 before inserting new 10 when at cap).

**Non-Goals:**
- Changing the `POST /v1/learning/cards` request/response schema.
- User-level word history or cross-device sync.
- Review-mode card batching (only `card_mode: new` is in scope).
- Offline generation or on-device AI.

## Decisions

### D1: Backend fills to `limit` via AI generation when pool is insufficient
**Decision**: If stored eligible words < `limit`, backend calls the AI generation pipeline for `limit − stored` additional words, then returns all `limit` words in one response.
**Rationale**: Simplest contract for mobile — always gets what it asked for. Avoids partial-batch fallback logic on mobile.
**Alternative considered**: Return what's available and let mobile retry. Rejected — increases mobile complexity and latency for first-launch.

### D2: Low-watermark at 3 unlearned words triggers background prefetch
**Decision**: `LearningSessionController` tracks the local unlearned count. When it drops to ≤ 3, it fires a background fetch of 10 words via `WordRepository`.
**Rationale**: 3 words gives enough runway to complete the background fetch before the queue empties. Avoids user-visible loading gaps.
**Alternative considered**: Prefetch at 50% drain. Rejected — triggers too frequently for small queues.

### D3: Cap enforcement on every batch insert, not periodically
**Decision**: `WordRepository.addBatch()` calls `localDb.pruneToMostRecent(990)` before inserting a new 10-word batch when total local words ≥ 1000.
**Rationale**: Keeps the cap deterministic and tied to the write path. No background pruning job needed.
**Alternative considered**: Scheduled background prune. Rejected — adds complexity without benefit given infrequent batch inserts.

### D4: Initial load is synchronous before learning screen renders
**Decision**: `main.dart` (or the screen loader) awaits the initial 10-word prefetch before navigating to the learning screen.
**Rationale**: Ensures the learning screen always has words available on first render. Simpler than showing a loading skeleton with async hydration.

## Risks / Trade-offs

- **[Risk] AI generation latency on first launch** → Mitigation: Show a loading indicator during the initial batch fetch. Backend generation for 10 words typically completes in < 5 s.
- **[Risk] Backend generation fails mid-batch** → Mitigation: Backend returns however many words it managed to generate (partial batch acceptable); mobile treats any non-zero response as success and retries on next low-watermark event.
- **[Risk] Concurrent background prefetches** → Mitigation: `WordRepository` uses a boolean flag `_prefetchInFlight` to debounce concurrent triggers.
- **[Risk] Prune deletes words with pending sync** → Mitigation: `pruneToMostRecent` already skips words with unsynced study events (existing behavior, confirmed in ObjectBox implementation).

## Migration Plan

1. Deploy backend fix first (no mobile change required for existing builds).
2. Ship mobile update with prefetch + cap enforcement.
3. No data migration needed — existing local ObjectBox stores are compatible.
4. Rollback: revert backend handler; mobile degrades gracefully (falls back to on-demand single-word fetch).

## Open Questions

- Should the low-watermark threshold (3) be a configurable constant or hard-coded? → Hard-code for now; extract to config if A/B testing is needed later.
