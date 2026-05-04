## 1. Express Backend Migration

- [x] 1.1 Add ExpressJS to backend dependencies and refresh the package lock.
- [x] 1.2 Refactor backend app creation to return an Express app while preserving store, generation service, and config injection.
- [x] 1.3 Move `/health`, `/v1/words/next`, `/v1/words/recent`, `/v1/study-events/sync`, and fallback 404 behavior into Express routes.
- [x] 1.4 Preserve existing successful response payloads and error payloads for valid requests.

## 2. Credential Configuration

- [x] 2.1 Add config parsing for `APP_CREDENTIALS_JSON`, timestamp skew, nonce TTL, and request body limits.
- [x] 2.2 Validate credential config shape and active credential entries without logging secret values.
- [x] 2.3 Add safe development/test credential fixtures for backend tests and local documentation.
- [x] 2.4 Update `.env.example` with placeholder app credential configuration and no real secrets.

## 3. Signature and Replay Utilities

- [x] 3.1 Implement canonical request construction from method, sorted path/query, timestamp, nonce, and content hash.
- [x] 3.2 Implement SHA-256 body hashing and HMAC-SHA-256 signature verification with timing-safe comparison.
- [x] 3.3 Implement an injectable in-memory nonce TTL cache keyed by app id and nonce.
- [x] 3.4 Add unit tests for canonical query sorting, body hashing, valid signatures, bad signatures, unknown app ids, expired timestamps, and replayed nonces.

## 4. Express Security Middleware

- [x] 4.1 Implement raw body capture middleware with endpoint body-size limits before JSON parsing.
- [x] 4.2 Implement coarse invalid-request rejection hooks before expensive HMAC or route work.
- [x] 4.3 Mount app credential middleware on `/v1/*` before the v1 router.
- [x] 4.4 Parse JSON from captured raw bodies only after app credential verification succeeds.
- [x] 4.5 Ensure invalid credential requests return only `400 { "error": "bad_request" }`.

## 5. API and Integration Tests

- [x] 5.1 Add a reusable test helper that signs GET and POST `/v1/*` requests.
- [x] 5.2 Update existing API, runtime, smoke, and PostgreSQL-backed tests to sign valid `/v1/*` requests.
- [x] 5.3 Add tests proving `/health` works without credentials.
- [x] 5.4 Add tests proving missing, malformed, tampered, expired, replayed, oversized, and unknown-app credential requests are rejected before route work.
- [x] 5.5 Add tests proving invalid `/v1/words/next` requests do not query the store or call LiteLLM.
- [x] 5.6 Add tests proving invalid `/v1/study-events/sync` requests do not parse study event payloads.

## 6. Documentation and Contracts

- [x] 6.1 Update `contracts/api.md` with required app credential headers for `/v1/*`.
- [x] 6.2 Update `docs/mvp-setup.md` and README backend notes for ExpressJS and signed local requests.
- [x] 6.3 Update `docs/app-credential-security.md` if implementation details differ from the proposal design.
- [x] 6.4 Document the single-instance in-memory nonce limitation and future Redis replacement path.

## 7. Verification

- [x] 7.1 Run the backend unit and API test suite with `npm test`.
- [x] 7.2 Run Docker Compose build/start health verification after the Express migration.
- [x] 7.3 Verify a signed `/v1/words/next` request succeeds and an unsigned `/v1/words/next` request returns `400`.
- [x] 7.4 Run `openspec status --change add-app-credential-security` and confirm all implementation tasks are complete before archive.
