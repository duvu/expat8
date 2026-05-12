## Why

The current learning flow is split between the legacy `/v1/words/next` path and the newer `/v1/learning/cards` path, so mobile still sends local word IDs/exclusion lists even though backend learner state already exists. We need one backend-owned card loading contract that returns 10 new words per load, records learner state server-side, and supports anonymous learners without preserving the old compatibility route.

## What Changes

- **BREAKING**: Remove `/v1/words/next` from the backend API, mobile client, tests, and API documentation.
- Make `/v1/learning/cards` the single card-loading endpoint for mobile.
- Change `/v1/learning/cards` to support a backend-owned "load 10 new words" request that does not accept client-provided exclude word IDs.
- Require anonymous learners to use a stable `anonymous_<uuid-v4>` identifier sent as `device_id`; signed-in requests continue to use bearer auth plus `device_id` for device/cache context.
- Have backend selection exclude words already learned, already represented in latest learner state, or already active/claimed in the learner's backend cache inventory.
- Have backend record returned batch items in backend cache/claim state so the next request can avoid duplicates without client-side word IDs.
- Keep mobile local cache and cache inventory sync as reconciliation/offline support, not as the primary duplicate-avoidance mechanism.
- Clean up old per-word fetch code paths and tests instead of preserving backward compatibility.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `backend-word-feed-sync`: Replace the legacy new-word feed contract with `/v1/learning/cards` as the single backend-owned card loading endpoint.
- `backend-postgres-persistence`: Persist the backend learner word state/cache claim data needed to avoid duplicate new-word selection for anonymous and signed-in learners.
- `mobile-local-cache-sync`: Update mobile cache refill behavior to request 10 backend-selected new words through `/v1/learning/cards` without sending exclude word IDs.
- `mobile-learning-session`: Update session card loading so swipe/new-card navigation uses the unified backend card endpoint and falls back only to local cached cards when remote loading fails.

## Impact

- Backend API: `backend/src/app.js`, `backend/src/word_store.js`, `backend/src/postgres_word_store.js`, route tests, API logging, and API contract docs.
- Backend schema/migrations: unique cache inventory indexes and any additive claim/upsert support required for `user_cached_words`.
- Mobile API/data layer: `BackendApiClient`, `WordRepository`, local anonymous device ID generation, cache inventory sync, and tests.
- Contracts/docs: `contracts/api.md` and this research-backed OpenSpec change.
- Deployment: breaking backend/mobile API cleanup; deploy coordinated backend and mobile builds because `/v1/words/next` will no longer exist.
