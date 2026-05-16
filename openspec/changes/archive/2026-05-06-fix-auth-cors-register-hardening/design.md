## Context

The E2E review in `docs/20260505-codebase-e2e-review.md` confirmed that browser-based registration fails before the signed POST request reaches the backend. Flutter Web sends custom `x-expat8-*` headers, so browsers first send an unsigned `OPTIONS` preflight. The current Express pipeline mounts `rejectMissingCredentialHeaders` and the HMAC guard before any CORS handling, so preflight receives `400 bad_request` and no `Access-Control-Allow-Origin`.

The review also found that PostgreSQL registration checks for an existing identifier before insert. Under concurrent duplicate registration, two requests can both pass the pre-check and the later insert can raise PostgreSQL unique violation `23505`, which currently escapes as `500 internal_error` instead of the public `409 user_exists` contract.

Mobile auth is functional but still lets obviously invalid input travel to the server and does not provide visible progress after the drawer/dialog closes. The project also has Linux SQLite FFI test fragility because `sqflite_common_ffi` needs a host `libsqlite3.so`.

## Goals / Non-Goals

**Goals:**

- Allow browser clients to call signed `/v1/*` APIs by making CORS preflight a deliberate unauthenticated exception before app credential verification.
- Preserve HMAC app credential enforcement for every non-OPTIONS `/v1/*` business request.
- Add configurable allowed origin behavior suitable for local development and production deployments.
- Convert PostgreSQL duplicate identifier races into `DuplicateUserError` and `409 user_exists`.
- Make registration input validation errors semantically distinct from sign-in credential errors.
- Add local auth form validation and visible in-progress feedback in the mobile UI.
- Make SQLite FFI test prerequisites explicit and repeatable for local Linux and CI.

**Non-Goals:**

- Replacing app credential security, password auth, session token format, or the existing `/v1/users/*` API shape.
- Adding OAuth, password reset, MFA, session expiry, or secure-storage migration for session tokens.
- Changing learning swipe behavior, word feed behavior, or adaptive proficiency behavior.
- Running destructive database operations or changing existing production data.

## Decisions

1. Add a small `/v1` CORS middleware before credential middleware.

   The middleware should set `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`, and `Access-Control-Max-Age` for `/v1/*`. If the request method is `OPTIONS`, it should return `204` before raw-body capture and HMAC verification. For all other methods, it should call `next()` so the existing security chain still runs.

   Alternative considered: require browsers to sign OPTIONS requests. Browsers generate preflight automatically and clients cannot reliably attach the HMAC payload as if it were a business request, so this would keep web clients broken.

2. Keep CORS configuration simple and explicit.

   Add `CORS_ALLOWED_ORIGIN` to runtime configuration with a development-friendly default, and document production deployments should set the expected origin. If credentials/cookies are not used for browser auth, `*` remains viable for development because user sessions are bearer headers plus app credentials, not ambient browser cookies.

   Alternative considered: implement a database-backed origin allowlist now. That is unnecessary for the immediate bug and adds operational surface before there are multiple public web origins.

3. Treat CORS as transport access, not authorization.

   CORS headers do not make a request trusted. They only allow browsers to send/read responses. Non-OPTIONS requests still require valid app credential headers, timestamp, nonce, content hash, and signature. Invalid credentials should still return the same public credential failure behavior, with CORS headers present so browser clients can read the error shape.

4. Catch PostgreSQL unique violations at the insert boundary.

   `registerUser` should still normalize input and can keep the pre-check for fast duplicate handling, but the insert must catch `err.code === '23505'` for the users identifier constraint and throw `DuplicateUserError`. This makes concurrent duplicate requests deterministic from the API caller's perspective.

   Alternative considered: remove the pre-check and rely only on `INSERT ... ON CONFLICT`. That is also valid, but preserving the current flow is a smaller patch and keeps error handling localized.

5. Add a registration input error class.

   `requireRegistrationInput` should throw a validation-oriented error, such as `InvalidUserInputError`, instead of `InvalidCredentialsError`. Route handling should map it to `400 bad_request`, while sign-in credential failure remains `401 invalid_credentials`.

6. Validate auth dialog fields before closing the dialog.

   The dialog should keep the user in context when the identifier is empty, email-like identifier is malformed, or password is too short. Use field-level error text and avoid sending network requests for invalid input. This reduces generic `400 bad_request` feedback and helps avoid unnecessary signed calls.

7. Show auth in-progress feedback outside the drawer.

   The controller already has an `isAuthInProgress` state. The screen should surface that state after the drawer closes, for example with an app-bar `LinearProgressIndicator`, modal progress overlay, or disabled actions plus visible indicator. This keeps the UI responsive and prevents the user from thinking the tap was ignored.

8. Make Linux SQLite test setup repeatable.

   Document installing `libsqlite3-dev` or provide a checked-in test command/script that sets a known `LD_LIBRARY_PATH` shim when the host only has `libsqlite3.so.0`. CI should use a base image with the library installed.

## Risks / Trade-offs

- Over-broad `Access-Control-Allow-Origin` in production -> Mitigate with `CORS_ALLOWED_ORIGIN` and deployment documentation for explicit production origin.
- Preflight bypass misunderstood as security bypass -> Mitigate by limiting the bypass to `OPTIONS` and adding tests proving unsigned POST still returns `400`.
- CORS headers missing on errors -> Mitigate with middleware mounted before the credential guard and tests for both preflight and invalid credential responses.
- Duplicate race tests are timing-sensitive -> Mitigate by adding a store-level test that simulates unique violation directly and an API-level concurrent duplicate test where practical.
- Mobile validation could reject non-email identifiers if product later allows usernames -> Mitigate by framing validation as "email-like identifier" for current UI copy and keeping backend normalization separate.
- SQLite FFI setup differs between developer machines and CI -> Mitigate by documenting both package installation and the temporary symlink fallback used in this repo.

## Migration Plan

1. Add runtime config and middleware without changing existing endpoint URLs or payloads.
2. Deploy backend with CORS allowed origin configured for the intended web frontend.
3. Verify `OPTIONS /v1/users/register` returns `204` with CORS headers and no HMAC requirement.
4. Verify signed register/sign-in/sign-out still work and unsigned non-OPTIONS `/v1/*` requests remain rejected.
5. Deploy mobile/web client validation changes after backend CORS support is live.

Rollback is straightforward: revert the middleware/config change and redeploy backend. Database schema changes are not required for this fix.

## Open Questions

- What exact production web origin should be configured for `CORS_ALLOWED_ORIGIN`: `<YOUR_BACKEND_URL>`, another app domain, or a comma-separated list if multiple frontends are expected?
- Should CI install `libsqlite3-dev` directly, or should the repository include a wrapper script for Linux Flutter tests?
