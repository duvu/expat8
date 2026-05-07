## Why

The end-to-end review confirmed that Flutter Web registration fails because browser CORS preflight requests hit the `/v1/*` app-credential guard and are rejected before the real signed request can run. The same review also found a PostgreSQL registration race that can turn concurrent duplicate registration into `500 internal_error` instead of the expected `409 user_exists`.

## What Changes

- Add first-class CORS handling for `/v1/*` browser clients so `OPTIONS` preflight is answered before app credential verification while normal API requests remain HMAC-protected.
- Add runtime CORS configuration for allowed origin and document safe development vs production values.
- Ensure all `/v1/*` responses that browser clients can receive include the expected CORS headers.
- Harden PostgreSQL user registration so unique identifier violations are mapped to `DuplicateUserError` and returned as `409 user_exists`, including concurrent registration races.
- Split registration validation errors from sign-in credential errors with a clearer backend error class while preserving current response contracts.
- Add client-side validation for auth dialogs so empty identifiers, malformed email-like identifiers, and short passwords are rejected before network calls.
- Add visible auth progress feedback while register/sign-in/sign-out requests are in flight.
- Ensure Linux Flutter tests that depend on `sqflite_common_ffi` can run in CI or documented local setup without missing `libsqlite3.so`.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `backend-app-credential-security`: CORS preflight for `/v1/*` must bypass HMAC verification safely, while non-OPTIONS API calls still require app credentials.
- `backend-postgres-persistence`: PostgreSQL persistence must map duplicate user identifier constraint violations to the public duplicate-registration contract.
- `mobile-learning-session`: Auth UI must validate user-entered credentials locally and expose visible in-progress feedback for auth actions.

## Impact

- Backend API layer: `backend/src/app.js`, app runtime config, CORS response headers, app credential middleware ordering, API tests.
- Backend persistence: `backend/src/postgres_word_store.js`, `backend/src/user_identity.js`, PostgreSQL store tests and registration race coverage.
- Mobile UI/session: `mobile/lib/src/ui/learning_screen.dart`, `mobile/lib/src/session/learning_session_controller.dart`, auth dialog tests.
- Test/development setup: Linux SQLite native dependency documentation or test shim setup for `sqflite_common_ffi`.
- Deployment/config docs: `contracts/api.md`, `docs/mvp-setup.md`, and the E2E review follow-up notes.
