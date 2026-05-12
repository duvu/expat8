## 1. API Contract And Test Baseline

- [x] 1.1 Update `contracts/api.md` to remove `/v1/words/next` and document `/v1/learning/cards` as the single card-loading endpoint.
- [x] 1.2 Add or update backend API tests for `POST /v1/learning/cards` returning up to 10 new words.
- [x] 1.3 Add backend API test coverage that `/v1/learning/cards` does not require or accept client-side word exclusion lists.
- [x] 1.4 Add backend API test coverage that `/v1/words/next` is no longer a supported route.
- [x] 1.5 Update mobile API client tests to expect `/v1/learning/cards` and no `/v1/words/next` calls.

## 2. Backend Data And Selection

- [x] 2.1 Add migration/schema support for idempotent `user_cached_words` owner-word uniqueness.
- [x] 2.2 Add store method for additive active cache/claim upserts without replacing the full cache inventory.
- [x] 2.3 Add store method or refactor existing selection to select up to 10 new words for a resolved learner context.
- [x] 2.4 Ensure new-word selection excludes signed-in user state, anonymous device state when relevant, and active cache/claim inventory.
- [x] 2.5 Ensure accepted study events continue to project into latest `user_word_states`.
- [x] 2.6 Add unit tests for anonymous selection, signed-in selection, duplicate claim idempotency, and anonymous-history exclusion.

## 3. Backend API Cleanup

- [x] 3.1 Implement canonical `POST /v1/learning/cards` request parsing with `device_id`, target language, limit 10, and optional new-card mode.
- [x] 3.2 Persist returned batch word IDs into active cache/claim inventory before completing the response.
- [x] 3.3 Remove the backend `/v1/words/next` route and any route-specific logging or helper logic.
- [x] 3.4 Remove or refactor backend store methods that only exist for `/v1/words/next`.
- [x] 3.5 Update backend tests and fixtures affected by route removal.

## 4. Mobile Identity And API Client

- [x] 4.1 Update mobile anonymous ID creation to generate `anonymous_<uuid-v4>` values.
- [x] 4.2 Decide and implement raw UUID normalization/reset behavior for existing local IDs in the breaking rollout.
- [x] 4.3 Replace mobile `fetchNewWords()` usage with a `/v1/learning/cards` client method.
- [x] 4.4 Remove mobile request construction for `excludeServerWordIds`, `excludeServerWordId`, and current-card word exclusion.
- [x] 4.5 Update mobile API client tests for signed and anonymous `/v1/learning/cards` requests.

## 5. Mobile Repository And Session Flow

- [x] 5.1 Update `WordRepository` refill/new-word logic to request batches of 10 through `/v1/learning/cards`.
- [x] 5.2 Ensure backend failures fall back only to eligible local cards and never to `/v1/words/next`.
- [x] 5.3 Preserve local cache inventory sync as reconciliation after cache prune/easy deletion.
- [x] 5.4 Update `LearningSessionController` tests for swipe/new-card behavior with unified backend refill.
- [x] 5.5 Remove obsolete mobile code paths and tests tied to per-word backend fetches.

## 6. Verification

- [x] 6.1 Run backend tests covering API, store, PostgreSQL integration, and route cleanup.
- [x] 6.2 Run mobile tests covering API client, local database, repository, and learning session controller.
- [x] 6.3 Run OpenSpec validation/status for `unify-learning-cards-backend-state`.
- [x] 6.4 Manually inspect `rg "words/next|exclude_server_word_id|fetchNewWords"` results and confirm only intentional historical docs or removed references remain.
