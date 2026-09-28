# Tasks

## 1. Specification

- [x] Create proposal describing fail-closed replay protection.
- [x] Create design describing error mapping, observability, and local-runtime behavior.
- [x] Add app-credential-security spec delta for unavailable storage and duplicate nonce scenarios.

## 2. Implementation

- [x] Map all PostgreSQL nonce-store insert failures to `NonceStorageUnavailableError`.
- [x] Return `503 REPLAY_PROTECTION_UNAVAILABLE` from the app-credential guard without invoking handlers.
- [x] Emit a safe structured log event for replay-store unavailability.
- [x] Preserve `InMemoryNonceCache` behavior for local/test no-database runtime.

## 3. Tests

- [x] Cover successful PostgreSQL nonce claims and duplicate nonce rejection.
- [x] Cover connection errors, timeout-like errors, pool errors, and missing schema errors.
- [x] Cover API-level handler bypass when replay storage is unavailable.

## 4. Validation

- [x] Run focused backend tests for app credentials and API guard behavior.
- [x] Run backend test suite.
- [x] Run lint, format check, and OpenSpec validation where available.
