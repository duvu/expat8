## MODIFIED Requirements

### Requirement: Backend verifies HMAC signatures over canonical requests
The backend SHALL verify app credential signatures using HMAC-SHA-256 over a canonical request containing method, sorted path and query, timestamp, nonce, and the SHA-256 hash of the raw request body. Signature comparison SHALL be performed in constant time regardless of the byte length of either operand.

#### Scenario: Signed query parameters are changed
- **WHEN** a client sends a request whose query parameters differ from the values used to compute the signature
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Signed body is changed
- **WHEN** a client sends a request whose raw body differs from the body hash used to compute the signature
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Unknown app id is supplied
- **WHEN** a client signs a request with an app id that is not configured as active
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Signatures with mismatched lengths are compared
- **WHEN** a client supplies a signature whose raw byte length differs from the expected signature
- **THEN** the backend's comparison does not terminate early due to length differences — both operands are normalized before the constant-time comparison

## ADDED Requirements

### Requirement: Nonce cache check-then-set concurrency is documented
The `InMemoryNonceCache.use()` operation SHALL include a code comment explaining that the check-then-set sequence is safe because Node.js processes events sequentially on a single thread, and each cache operation completes without yielding.

#### Scenario: Concurrent requests arrive in the same event loop tick
- **WHEN** two requests carrying the same nonce are received
- **THEN** only the first request passes nonce verification; the second is rejected
