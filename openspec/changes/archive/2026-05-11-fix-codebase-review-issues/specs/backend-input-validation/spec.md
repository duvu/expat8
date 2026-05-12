## Purpose
Define centralised input validation at the API boundary for language codes, timestamps, and bearer token format to reject malformed requests before business logic runs.

## ADDED Requirements

### Requirement: Backend validates target language codes at API boundary
The backend SHALL reject requests that specify an unsupported `target_language` value.

#### Scenario: Valid language code is supplied
- **WHEN** a client sends a request with `target_language=en` or another configured valid code
- **THEN** the backend processes the request normally

#### Scenario: Unknown language code is supplied
- **WHEN** a client sends a request with an unrecognized `target_language` value (e.g. `xx`, empty string)
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

### Requirement: Backend validates `occurred_at` timestamp before processing study events
The backend SHALL reject study events whose `occurred_at` field is not a parseable ISO 8601 date.

#### Scenario: Valid ISO 8601 timestamp is supplied
- **WHEN** a client sends a study event with a valid `occurred_at` value
- **THEN** the backend stores the event and computes `next_review_at` correctly

#### Scenario: Invalid timestamp is supplied
- **WHEN** a client sends a study event with an unparseable `occurred_at` value (e.g. `"not-a-date"`)
- **THEN** the backend returns `400` with `{ "error": "bad_request" }` and does not store the event

### Requirement: Backend rejects requests with invalid bearer tokens explicitly
The backend SHALL return `401` when a request carries an `Authorization: Bearer` header whose token does not resolve to an active session, rather than silently treating the request as unauthenticated.

#### Scenario: Missing Authorization header on optional-auth endpoint
- **WHEN** a client sends a request to an optional-auth endpoint without an Authorization header
- **THEN** the backend processes the request as anonymous

#### Scenario: Invalid bearer token on optional-auth endpoint
- **WHEN** a client sends a request to an optional-auth endpoint with an `Authorization: Bearer <invalid>` header
- **THEN** the backend returns `401` with `{ "error": "invalid_session" }`

#### Scenario: Valid bearer token on optional-auth endpoint
- **WHEN** a client sends a request with a valid `Authorization: Bearer <token>` header
- **THEN** the backend resolves the session and processes the request as authenticated
