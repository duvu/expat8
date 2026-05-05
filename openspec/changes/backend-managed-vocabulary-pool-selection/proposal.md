## Why

The current backend can call LiteLLM while a mobile user is waiting for `/v1/words/next`, coupling user latency and availability to AI generation. The product direction now requires backend-managed vocabulary inventory and backend-owned card selection so mobile requests read from prepared database state, avoid duplicate cards, and preserve every learning attempt.

## What Changes

- Decouple AI vocabulary generation from mobile word/card requests.
- Add backend vocabulary pool management that fills each target language to at least 1000 usable words by generating on a minute cadence, then adds 10 new words per day after the pool is full.
- Add backend card selection that returns database-backed learning cards with a target mix of 15% new words and 85% review words.
- Track active mobile cache inventory on the backend so words already stored on a user's device are not returned again as replacement/new cards.
- Preserve every study attempt as an append-only event while maintaining latest per-user/device word state for efficient selection.
- Change `easy` semantics so an easy-rated word is removed from the mobile local cache and excluded from future new-card selection for that learner.
- Narrow the existing mobile prefetch/refresh direction: mobile should cache, report inventory, queue study events, and request refill batches, while backend owns pool freshness and selection policy.
- **BREAKING**: `/v1/words/next` and any replacement card endpoint must not trigger AI generation during the request path.

## Capabilities

### New Capabilities

- `backend-vocabulary-pool-management`: Backend scheduler and generation policy for maintaining a prepared vocabulary pool.
- `backend-learning-card-selection`: Backend selection of new/review learning cards from database state with target mix and fallback behavior.
- `backend-user-cache-inventory`: Backend tracking of active mobile local cache inventory for duplicate avoidance.

### Modified Capabilities

- `ai-vocabulary-generation`: AI generation becomes asynchronous pool maintenance and is removed from mobile request handling.
- `backend-word-feed-sync`: Word feed and study-event sync semantics change to use backend selection state and append-only event/state projection.
- `backend-postgres-persistence`: Persistence must support generation runs, scheduler locking, latest word state uniqueness, and user/device cache inventory.
- `mobile-local-cache-sync`: Mobile must sync cache inventory, remove easy-rated words locally, and preserve pending study events before deletion.
- `mobile-learning-session`: Mobile card flow must consume backend-selected batches and treat easy-rated words as completed/replaced for the learner.

## Impact

- Backend API: `/v1/words/next`, potential new `/v1/learning/cards`, study event endpoints, and a cache inventory endpoint.
- Backend runtime: scheduler startup/shutdown, generation lock, pool count inspection, and daily generation policy.
- Backend services: `VocabularyGenerationService`, word store interfaces, card selection service, study-event state projection.
- Backend schema: new generation run/lock/cache tables and clarified uniqueness for user/device word state.
- Mobile data layer: local cache inventory reporting, replacement batch refill, easy-rating local deletion, sync queue preservation.
- Mobile session behavior: card source ratio moves to backend batch selection while local cache remains the instant/offline display source.
- Docs/tests: API contract, setup/config docs, scheduler tests, selection tests, persistence tests, mobile local cache/session tests, and end-to-end smoke coverage.
