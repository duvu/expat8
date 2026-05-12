## Context

The backend already has the primitives needed for backend-owned learning state: `study_events`, `user_word_states`, `user_cached_words`, optional bearer sessions, and a `/v1/learning/cards` route. The mobile app still has a split path: it can refill through `/v1/learning/cards`, but `getNewWordWithFallbackResult()` still builds `excludeServerWordIds` and calls `/v1/words/next` for one word at a time. That split keeps duplicate avoidance partly on the client and makes the API contract harder to reason about.

This change deliberately makes a breaking cleanup. `/v1/words/next` is removed instead of preserved. `/v1/learning/cards` becomes the only mobile card-loading endpoint and supports loading 10 new words without client-provided word IDs.

## Goals / Non-Goals

**Goals:**

- Make `/v1/learning/cards` the single backend endpoint used by mobile to load learning cards/new words.
- Return up to 10 backend-selected new words per new-word load.
- Stop accepting or sending client-side `exclude_server_word_id` values.
- Persist backend cache/claim state when a batch is returned so later requests avoid duplicates without client-supplied IDs.
- Use stable anonymous learner IDs in the form `anonymous_<uuid-v4>` when no user session exists.
- Keep signed-in selection user-scoped while retaining `device_id` for local cache/device context.
- Clean up backend, mobile, contracts, and tests for the removed `/v1/words/next` route.

**Non-Goals:**

- Preserving compatibility for old mobile builds that still call `/v1/words/next`.
- Adding a second new endpoint such as `/v1/learning/new-words`.
- Replacing the existing study-event sync and app credential signing model.
- Building a full spaced-repetition algorithm beyond the current projected state and review scheduling behavior.
- Removing `/v1/words/recent` unless implementation finds it is no longer used by any supported flow.

## Decisions

### D1: Use `/v1/learning/cards` as the sole card-loading path

All mobile remote card loading should go through `/v1/learning/cards`. The legacy `/v1/words/next` route, client method, tests, and docs should be deleted. This avoids a compatibility branch where one path is backend-owned and another still depends on client exclusions.

Alternative considered: keep `/v1/words/next` as a deprecated compatibility route. This was rejected because the product decision is a clean break and the old route keeps duplicate avoidance split across client and server.

### D2: Prefer `POST /v1/learning/cards` for batch claim semantics

Returning a batch should also record the returned word IDs into backend cache/claim state. That is a side effect, so `POST /v1/learning/cards` is the clearest contract. If the code keeps `GET` temporarily during refactor, it should still be treated as an implementation step toward the canonical `POST` contract, not as a second public path.

Alternative considered: keep the current `GET /v1/learning/cards` shape and only change query parameters. This is less churn but obscures the fact that returning a batch mutates claim/cache state.

### D3: Represent anonymous learners with prefixed `device_id`

Anonymous learners use a stable `device_id` formatted as `anonymous_<uuid-v4>`. This reuses existing device-scoped backend tables while making anonymous identity explicit in logs, database rows, and request contracts. Existing raw UUID local IDs are not a public compatibility contract; implementation can normalize old values by prefixing them or generate a fresh anonymous ID as part of the coordinated breaking rollout.

Alternative considered: create anonymous rows in `users`. This adds identity model complexity before it is needed because selection already supports `device_id` plus `user_id IS NULL`.

### D4: Use `user_cached_words` as active cache/claim inventory

When `/v1/learning/cards` returns new words, backend should upsert those word IDs into `user_cached_words` for the resolved owner/context before returning. Mobile can still submit full cache inventory after local pruning or easy-rated deletion, but that sync becomes reconciliation rather than the primary mechanism that prevents duplicate batches.

This requires additive upsert support in addition to the existing full-replace inventory sync. It also requires unique owner/word indexes so repeated claims are idempotent.

Alternative considered: wait for mobile to sync cache inventory after each response. This creates a race where repeated requests can return duplicates if the first response is processed before inventory sync succeeds.

### D5: Keep `user_word_states` for studied state, not initial assignment state

`user_word_states` should continue to represent words after a study event is accepted. New words that have only been returned to the device should be tracked in `user_cached_words`. This avoids making an assigned-but-unstudied word look like a due review item in the current selection logic.

Alternative considered: add a `new` or `assigned` status in `user_word_states`. This is possible later but requires careful selector changes so assigned words are excluded from new selection without becoming review candidates.

### D6: Signed-in selection must account for anonymous history

When a signed-in request includes a bearer session and `device_id`, backend selection should avoid words from both the signed-in user's state and the device's anonymous state/cache context. Implementation can either merge anonymous state on sign-in/register or query a union during selection. The first implementation should choose the smaller reliable path, but it must not let a just-signed-in user immediately receive words already studied anonymously on that device.

## Risks / Trade-offs

- [Risk] Old clients break when `/v1/words/next` is removed -> Mitigation: coordinated backend/mobile rollout is accepted by scope; tests and docs should make the break explicit.
- [Risk] A request can claim words but fail before mobile stores them -> Mitigation: batch size is small; later cleanup can add `claimed_at` TTL or inventory reconciliation if stranded claims become visible in telemetry.
- [Risk] `user_cached_words` now means both active local cache and recently claimed batch -> Mitigation: document the broader active inventory semantics and keep full inventory sync authoritative for pruning/deletion reconciliation.
- [Risk] Current `/v1/learning/cards` returns a 15/85 new/review mix -> Mitigation: add explicit new-word mode or make the endpoint default for this request return 10 new cards, while preserving one route.
- [Risk] Signed-in users may repeat anonymous words if state is not merged -> Mitigation: include union/merge behavior in specs and tests.

## Migration Plan

1. Update API contract and tests to define `POST /v1/learning/cards` as the canonical card-loading request and remove `/v1/words/next`.
2. Add backend store support for selecting 10 new words by resolved owner and upserting returned IDs into cache/claim inventory.
3. Add unique indexes for cache inventory owner/word idempotency.
4. Update mobile anonymous ID generation to use `anonymous_<uuid-v4>`.
5. Update mobile repository/API client to call `/v1/learning/cards` only and remove exclude-word request logic.
6. Update mobile session fallback to use local cache/offline behavior when the unified endpoint fails.
7. Remove obsolete backend/mobile code and tests for `/v1/words/next`.

Rollback is a coordinated version rollback, not a compatibility route inside this change. If deployment fails, revert the backend/mobile release together or redeploy the previous version that still contains `/v1/words/next`.

## Open Questions

- Should `card_mode: "new"` be explicit in the request, or should `POST /v1/learning/cards` default to 10 new cards for this release?
- For old local raw UUID device IDs, should mobile prefix the existing value or generate a fresh anonymous ID during the breaking rollout?
- Should anonymous-to-signed-in history be merged at sign-in/register time, or should selection query both signed-in and anonymous owner scopes?
