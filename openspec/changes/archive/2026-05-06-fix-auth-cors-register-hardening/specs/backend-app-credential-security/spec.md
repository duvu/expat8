## ADDED Requirements

### Requirement: Backend supports browser CORS preflight for public API routes
The backend SHALL respond to browser CORS preflight requests for `/v1/*` routes before app credential verification while preserving app credential verification for non-OPTIONS API requests.

#### Scenario: Browser preflights a registration request
- **WHEN** a browser sends `OPTIONS /v1/users/register` with an `Origin`, `Access-Control-Request-Method: POST`, and requested `x-expat8-*` headers
- **THEN** the backend returns `204` with CORS allow headers and does not require app credential headers on the preflight request

#### Scenario: Browser preflights a signed learning request
- **WHEN** a browser sends `OPTIONS` to a `/v1/*` learning endpoint with requested app credential headers
- **THEN** the backend returns `204` with allowed methods and allowed headers that permit the subsequent signed request

#### Scenario: Unsigned non-OPTIONS request remains rejected
- **WHEN** a client sends `POST /v1/users/register` without valid app credential headers
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

### Requirement: Backend includes CORS headers on public API responses
The backend SHALL include configured CORS response headers on `/v1/*` responses so browser clients can read both successful responses and expected API error responses.

#### Scenario: Signed registration succeeds from an allowed origin
- **WHEN** a browser sends a valid signed `POST /v1/users/register` request from the configured allowed origin
- **THEN** the backend response includes `Access-Control-Allow-Origin` matching the configured policy

#### Scenario: Signed registration fails with duplicate user
- **WHEN** a browser sends a valid signed duplicate registration request from the configured allowed origin
- **THEN** the backend returns `409` with `{ "error": "user_exists" }` and includes CORS headers

#### Scenario: Invalid app credential response is readable by browser client
- **WHEN** a browser sends a non-OPTIONS `/v1/*` request with invalid app credential headers
- **THEN** the backend returns the app credential error response with CORS headers present

### Requirement: Backend exposes runtime CORS origin configuration
The backend SHALL read the allowed CORS origin policy from runtime configuration without committing production origins or secrets into source code.

#### Scenario: CORS origin is configured
- **WHEN** the backend starts with `CORS_ALLOWED_ORIGIN` set
- **THEN** `/v1/*` CORS responses use that configured origin policy

#### Scenario: CORS origin is omitted in development
- **WHEN** the backend starts without `CORS_ALLOWED_ORIGIN`
- **THEN** the backend uses its documented development default and continues to require app credentials on non-OPTIONS `/v1/*` requests
