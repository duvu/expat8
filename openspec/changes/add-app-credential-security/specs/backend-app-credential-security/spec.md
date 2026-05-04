## ADDED Requirements

### Requirement: Backend protects public API routes with app credentials
The backend SHALL require valid app credential verification before handling any `/v1/*` API request.

#### Scenario: Health check remains unauthenticated
- **WHEN** a client sends `GET /health` without app credential headers
- **THEN** the backend returns the minimal health response without requiring app credential verification

#### Scenario: Public API request is missing credentials
- **WHEN** a client sends a request to any `/v1/*` endpoint without the required app credential headers
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Valid public API request reaches the route handler
- **WHEN** a client sends a `/v1/*` request with a valid app id, timestamp, nonce, content hash, and signature
- **THEN** the backend processes the matching API route normally

### Requirement: Backend verifies HMAC signatures over canonical requests
The backend SHALL verify app credential signatures using HMAC-SHA-256 over a canonical request containing method, sorted path and query, timestamp, nonce, and the SHA-256 hash of the raw request body.

#### Scenario: Signed query parameters are changed
- **WHEN** a client sends a request whose query parameters differ from the values used to compute the signature
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Signed body is changed
- **WHEN** a client sends a request whose raw body differs from the body hash used to compute the signature
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Unknown app id is supplied
- **WHEN** a client signs a request with an app id that is not configured as active
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

### Requirement: Backend rejects expired and replayed credential requests
The backend SHALL reject credential requests outside the configured timestamp window and SHALL reject repeated nonces for the same app id within the replay window.

#### Scenario: Timestamp is outside the accepted window
- **WHEN** a client sends a signed `/v1/*` request with a timestamp older or newer than the configured skew window
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Nonce is replayed
- **WHEN** a client sends a second signed `/v1/*` request using the same app id and nonce within the replay window
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

### Requirement: Backend limits request bodies before JSON parsing
The backend MUST enforce configured request body size limits before JSON parsing or business route handling occurs.

#### Scenario: GET request contains a body
- **WHEN** a client sends a signed GET request to `/v1/*` with a non-empty body
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: POST body exceeds the configured limit
- **WHEN** a client sends a signed POST request to `/v1/*` with a body larger than the configured endpoint limit
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

### Requirement: Backend loads app credentials from runtime configuration
The backend SHALL load active app credential definitions from runtime configuration and SHALL NOT require any real app secret to be committed to the repository.

#### Scenario: Active credential is configured
- **WHEN** the backend starts with an active app credential in runtime configuration
- **THEN** requests signed with that credential can pass app credential verification

#### Scenario: Credential is not active
- **WHEN** the backend receives a request signed with a credential that is missing, malformed, or not active
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

### Requirement: Backend composes security checks as ExpressJS middleware
The backend SHALL use ExpressJS middleware ordering so app credential checks run before `/v1/*` routers, database access, LiteLLM calls, and JSON body parsing.

#### Scenario: Invalid credential request targets a word feed endpoint
- **WHEN** a client sends an invalid credential request to `/v1/words/next`
- **THEN** the backend rejects the request before querying the word store or calling LiteLLM

#### Scenario: Invalid credential request targets study event sync
- **WHEN** a client sends an invalid credential request to `/v1/study-events/sync`
- **THEN** the backend rejects the request before parsing the body as a study event payload
