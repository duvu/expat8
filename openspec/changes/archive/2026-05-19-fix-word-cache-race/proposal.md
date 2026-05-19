## Why

`PUT /v1/user-word-cache` fails with a 500 duplicate-key error when two concurrent calls race on the UNIQUE partial index in `user_cached_words`. This happens at every app startup that triggers both a cache inventory sync and a word-cache replacement at the same time. Secondary issues: rate-limit config values are defined but never wired into the limiter (dead config), and auth error messages in the mobile app are not actionable (e.g. 401 on sign-in does not suggest registering).

## What Changes

- **Backend**: Add `ON CONFLICT DO NOTHING` to the `INSERT` in `replaceCachedWordIds` (`postgres_word_store.js`) so concurrent word-cache replacements are idempotent and never produce a 500.
- **Backend**: Wire `authRateLimitRegister` and `authRateLimitSignIn` config values into `createRateLimiters()` so the configured limits are actually enforced.
- **Mobile**: Improve `_authFailureMessage` so a 401 on sign-in tells the user their account was not found and prompts them to register; a 429 explains the rate-limit in plain language.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `backend-postgres-persistence`: word-cache replacement (`PUT /v1/user-word-cache`) SHALL be idempotent under concurrent calls — no 500 on duplicate inserts.

## Impact

- `backend/src/postgres_word_store.js` — `replaceCachedWordIds` INSERT statement
- `backend/src/runtime.js` or `backend/src/rate_limit.js` — `createRateLimiters()` call-site
- `backend/src/config.js` — `authRateLimitRegister` / `authRateLimitSignIn` already defined; just needs to be plumbed through
- `mobile/lib/src/session/learning_session_controller.dart` — `_authFailureMessage` helper
- No API contract changes; no migration required; no breaking changes
