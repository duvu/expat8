## Context

The current system has the core pieces for vocabulary generation, persistence, mobile local cache, and study-event sync, but their responsibilities are still mixed. `GET /v1/words/next` can call `VocabularyGenerationService.generateAndStore()` when stored inventory is insufficient, so a mobile learning request can block on LiteLLM. Mobile also has an in-progress prefetch/refresh direction that treats the device as the owner of vocabulary freshness.

The desired model is backend-first: backend continuously prepares vocabulary, mobile requests prepared cards, mobile reports study/cache state, and backend avoids returning words that have already been learned or are already cached on that device. The reference design is documented in `docs/backend-vocabulary-generation-and-selection.md`.

## Goals / Non-Goals

**Goals:**

- Move AI generation out of mobile request handling.
- Maintain a backend vocabulary pool of at least 1000 usable words per target language.
- Generate new words every minute while the pool is below target, then add 10 words per day after the pool is full.
- Select learning cards from database state with a target mix of 15% new and 85% review.
- Preserve every study attempt in `study_events`, including repeated attempts for the same word.
- Maintain latest per-user/device word state for selection.
- Track active mobile local cache inventory on the backend to avoid returning cached duplicates.
- Treat `easy` as completed for the current learner: remove locally, sync event, and exclude from future new-card selection.

**Non-Goals:**

- Adding a full spaced-repetition algorithm beyond the simple state projection needed for selection.
- Adding editorial review workflows for AI-generated vocabulary.
- Replacing app credential security, user sessions, or the current study-event idempotency model.
- Implementing multi-device conflict resolution beyond signed-in user/device state merge basics.
- Running destructive data migrations outside normal schema evolution.

## Decisions

### D1: Backend scheduler owns vocabulary freshness

Add a runtime scheduler that periodically inspects usable word count per target language. If a language has fewer than `VOCAB_POOL_MIN_SIZE` words, it schedules generation on a minute cadence. If the pool is full, it runs a daily top-up of `VOCAB_DAILY_GENERATION_COUNT` words.

Alternative considered: keep mobile daily refresh and ask mobile to trigger generation indirectly. That keeps AI availability coupled to user activity and does not guarantee backend inventory readiness for new users.

### D2: Mobile card requests never call AI

`/v1/words/next` can remain for compatibility, but it must become database-only. A new batch endpoint such as `/v1/learning/cards` should be introduced for the 15/85 new/review mix and clearer response metadata.

Alternative considered: keep `/v1/words/next` as the only endpoint and overload query params. That is less disruptive but makes a batch ratio contract awkward because a single-card request cannot reliably express 15%/85%.

### D3: Use append-only events plus latest-state projection

Keep `study_events` as the durable event log and idempotency surface. Add or finish projection into `user_word_states` on every accepted event so selection can query latest status efficiently without scanning the full event log.

Alternative considered: derive state from `study_events` on every card request. That preserves fewer tables but will become expensive and harder to reason about as event volume grows.

### D4: Backend tracks mobile cache inventory

Add `user_cached_words` and a signed endpoint where mobile reports the current local `server_word_id` list. Backend uses this as an exclusion set for new/replacement card selection.

Alternative considered: pass up to 1000 cached IDs on every card request. That avoids a table but inflates request size and duplicates state transfer across normal learning flow.

### D5: Treat `easy` as completed/excluded

For this change, an easy-rated word is no longer an active review item for that learner. Mobile removes it from `local_words`, backend records the event, and backend marks the word as completed/excluded from future new-card selection for the learner.

Alternative considered: keep current local behavior where `easy` schedules review in three days. That conflicts with the requested "xóa khỏi local database" and "không trả ra cho user đó nữa" behavior.

### D6: Support anonymous and signed-in ownership

Selection and state projection must work with `device_id` for anonymous learners and `user_id` for signed-in learners. Signed-in state should prefer `user_id` while retaining `device_id` for cache inventory and offline context.

Alternative considered: require sign-in for the new selection behavior. That would break optional-login learning and is outside the current product model.

## Risks / Trade-offs

- [Risk] Multiple backend instances generate duplicate batches -> Mitigate with Postgres advisory locks or a `scheduler_locks` table with expiration.
- [Risk] AI generation fails repeatedly and pool remains below target -> Mitigate with logged generation runs, retry on next tick, and DB-only mobile responses that degrade gracefully when inventory is low.
- [Risk] `easy` as permanent exclusion reduces long-term spaced repetition -> Mitigate by documenting semantics now; introduce a separate mastered/review policy later if product changes.
- [Risk] Mobile cache inventory can be stale -> Mitigate by treating inventory as advisory and syncing it at startup, after refill, and after easy-rated deletion.
- [Risk] Existing `mobile-vocabulary-prefetch-refresh` change conflicts with backend ownership -> Mitigate by narrowing mobile work to local cache, inventory sync, and backend batch refill.
- [Risk] 15/85 ratio cannot be met for small requests or cold users -> Mitigate by applying the ratio over batches/rolling windows and returning actual mix metadata.

## Migration Plan

1. Add backend schema support: generation run tracking, scheduler lock, cache inventory, and uniqueness/indexes for latest user/device word state.
2. Add scheduler and generation pool config, but keep it disabled or no-op until tests cover lock and cadence behavior.
3. Remove AI fallback from `/v1/words/next`; keep database-only behavior and document possible empty responses.
4. Add latest-state projection from study event ingestion.
5. Add cache inventory endpoint and backend card selection service.
6. Add batch learning-card endpoint and update mobile refill flow to use it.
7. Update mobile easy handling: persist event, delete local word, sync inventory, request replacement/refill.
8. Deploy backend first with scheduler enabled, then mobile client changes.

Rollback:

- Disable scheduler with config if generation causes operational issues.
- Keep existing `/v1/words/next` database-only compatibility route.
- Mobile can fall back to local cache and queued study-event sync if the new card endpoint is unavailable.

## Open Questions

- Should `easy` be permanent exclusion, or should it become a very long review interval after the first release of this change?
- Should the 1000-word pool target be per language only, or per language plus CEFR distribution?
- Should signed-in users merge historical anonymous `device_id` word state immediately at login, or only use signed-in state going forward?
- Should the first implementation use a table-based scheduler lock or Postgres advisory locks?
