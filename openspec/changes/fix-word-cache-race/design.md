## Context

`PUT /v1/user-word-cache` replaces the device's cached word-id list. The handler calls `replaceCachedWordIds` in `postgres_word_store.js`, which:
1. Deletes all `user_cached_words` rows for the device (where `user_id IS NULL`).
2. Inserts each new word id in a loop.

Under READ COMMITTED isolation, two concurrent requests both complete their DELETE phase before either has committed, then both proceed to INSERT the same word ids. The second INSERT hits the `UNIQUE` partial index (`idx_user_cached_words_device_word`) and throws, producing a 500.

The endpoints is called on every app startup: once by cache inventory sync and once by word-cache replacement, so the race is highly reproducible.

## Goals / Non-Goals

**Goals:**
- Eliminate the 500 from concurrent `PUT /v1/user-word-cache` calls.
- Wire the dead rate-limit config (`authRateLimitRegister` / `authRateLimitSignIn`) so configured values are enforced.
- Improve mobile auth error messages for 401 and 429 responses.

**Non-Goals:**
- Changing the semantics of word-cache replacement (last-writer-wins remains acceptable).
- Moving to a serializable transaction or advisory locks (over-engineered for this access pattern).
- Redesigning the rate-limiter to use a shared store (out of scope).

## Decisions

### Decision 1 — `ON CONFLICT DO NOTHING` on the word-cache INSERT

**Chosen:** Add `ON CONFLICT DO NOTHING` to the INSERT inside `replaceCachedWordIds`.

**Rationale:** Both concurrent requests are trying to store the same list of word ids. The uniqueness constraint guarantees no duplicate rows will be present regardless of which request "wins" each insert. The end state is identical to a serialized execution. This is a one-line fix with no observable semantic difference for clients.

**Alternatives considered:**
- *Serializable isolation* — would cause one request to retry or fail at transaction level; more complexity, no benefit.
- *Advisory lock per device* — adds locking overhead on every startup; unnecessary.
- *UPSERT (ON CONFLICT DO UPDATE)* — equivalent here since there are no columns to update beyond the unique key, so DO NOTHING is simpler.

### Decision 2 — Wire dead rate-limit config via `createRateLimiters(opts)`

**Chosen:** Pass `authRateLimitRegister` and `authRateLimitSignIn` from `config` into `createRateLimiters()` as options.

**Rationale:** The values are already defined in `config.js` with sensible defaults matching the spec (10/15 min and 20/15 min). The only bug is they are never passed to the factory. Plumbing them through requires changing the call-site in `runtime.js` and the function signature in `rate_limit.js`.

### Decision 3 — 401 message distinguishes "not found" from "wrong password"

**Chosen:** The backend 401 response for sign-in already returns `{ "error": "..." }`. Add `"reason": "user_not_found"` to the 401 when the identifier is not found (vs. wrong password). The mobile client reads this field to show "No account found — please register" vs. the existing "Email or password incorrect".

**Alternative considered:** Always say "Email or password incorrect" (current behavior) for security. This is acceptable for a language-learning app with no sensitive data; actionable messages are more important here than enumeration protection.

## Risks / Trade-offs

- **[Race still possible at schema level]** → `ON CONFLICT DO NOTHING` handles duplicate inserts atomically; the residual risk (stale rows from the DELETE of one tx, combined with a re-insert by the other) is prevented because both requests insert the *same* set of word ids. Any leftover rows from a partially deleted set are acceptable (worst case: a few extra cached ids until the next replacement).
- **[Rate-limit config change]** → defaults match the existing spec values, so no behavioral change for production unless `APP_CREDENTIALS_JSON` / env overrides are set with different values.
- **[401 reason field]** → clients that don't read `reason` continue to work unchanged; it is purely additive.

## Migration Plan

- No database migration required.
- No client rebuild required for backend changes alone (the 401 `reason` field is additive).
- Mobile change requires a Flutter release build and app update.
- Deploy backend first; mobile update can follow independently.
