## 1. Baseline and Regression Reproduction

- [x] 1.1 Reproduce current browser-style `OPTIONS /v1/users/register` failure with Origin and requested `x-expat8-*` headers.
- [x] 1.2 Add backend API regression tests proving preflight currently needs CORS behavior and unsigned non-OPTIONS `/v1/*` requests still fail.
- [x] 1.3 Add PostgreSQL store/API regression coverage for duplicate user identifier unique-violation handling.
- [x] 1.4 Add mobile widget/controller tests for auth dialog validation and visible auth in-progress feedback.

## 2. Backend CORS Support

- [x] 2.1 Add runtime config for `CORS_ALLOWED_ORIGIN` with documented development default.
- [x] 2.2 Implement `/v1` CORS middleware before raw-body capture and app credential middleware.
- [x] 2.3 Return `204` for valid browser preflight requests without requiring app credential headers.
- [x] 2.4 Ensure CORS headers are present on successful `/v1/*` responses and expected API error responses.
- [x] 2.5 Verify invalid non-OPTIONS `/v1/*` requests remain rejected by app credential security.

## 3. Registration Persistence Hardening

- [x] 3.1 Add an invalid registration input error class separate from invalid sign-in credentials.
- [x] 3.2 Update registration input validation to throw the new validation error while preserving `400 bad_request`.
- [x] 3.3 Catch PostgreSQL unique violation `23505` during user insert and map identifier conflicts to `DuplicateUserError`.
- [x] 3.4 Ensure non-duplicate PostgreSQL errors still surface through the normal internal error path.
- [x] 3.5 Remove unnecessary in-memory password re-verification after successful registration if it is still present.

## 4. Mobile Auth UX

- [x] 4.1 Add local validation for empty identifier, malformed email-like identifier, and too-short password in register/sign-in dialogs.
- [x] 4.2 Keep the auth dialog open and display field-level errors when local validation fails.
- [x] 4.3 Prevent backend auth calls when dialog validation fails.
- [x] 4.4 Add visible auth progress feedback on the learning screen while register/sign-in/sign-out is in progress.
- [x] 4.5 Preserve existing auth success/error SnackBar behavior after auth requests complete.

## 5. Test Environment and Documentation

- [x] 5.1 Document the Linux `libsqlite3.so` requirement for Flutter SQLite FFI tests.
- [x] 5.2 Add or document a repeatable local test command for hosts that only expose `libsqlite3.so.0`.
- [x] 5.3 Update `contracts/api.md` with CORS preflight behavior and CORS config semantics.
- [x] 5.4 Update `docs/20260505-codebase-e2e-review.md` or related follow-up docs with fixed/remaining status.

## 6. Verification

- [x] 6.1 Run backend tests covering app credentials, CORS preflight, registration, PostgreSQL store behavior, and identity APIs.
- [x] 6.2 Run Flutter analyzer and mobile tests covering auth dialog validation and progress feedback.
- [x] 6.3 Manually smoke test browser-style CORS preflight against the local backend.
- [x] 6.4 Run `openspec validate fix-auth-cors-register-hardening`.
- [x] 6.5 Run `openspec status --change fix-auth-cors-register-hardening` and confirm all implementation tasks are complete before archive.
