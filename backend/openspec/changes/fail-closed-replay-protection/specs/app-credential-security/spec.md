# app-credential-security Specification Delta

## ADDED Requirements

### Requirement: Replay protection MUST be authoritative

The backend MUST reject protected app-credential requests when the configured nonce store cannot authoritatively claim or reject the request nonce.

#### Scenario: nonce store fails during a protected request

- **GIVEN** a request with an otherwise valid app signature
- **AND** the configured PostgreSQL nonce store errors or times out
- **WHEN** the app-credential guard verifies the request
- **THEN** the backend returns `503` with `{"error":"REPLAY_PROTECTION_UNAVAILABLE"}`
- **AND** no application route handler is invoked
- **AND** the request is not reported as authenticated

#### Scenario: missing nonce storage schema

- **GIVEN** a request with an otherwise valid app signature
- **AND** the configured PostgreSQL nonce table is missing
- **WHEN** the app-credential guard verifies the request
- **THEN** the backend returns `503` with `{"error":"REPLAY_PROTECTION_UNAVAILABLE"}`
- **AND** no application route handler is invoked

#### Scenario: duplicate nonce

- **GIVEN** a nonce was already claimed for the same app id
- **WHEN** the signed request is repeated within the nonce TTL
- **THEN** the request is rejected without invoking the route handler

#### Scenario: in-memory cache remains available without database configuration

- **GIVEN** the backend is running without a configured database-backed nonce store
- **WHEN** a protected request has a valid app signature and fresh nonce
- **THEN** the in-memory nonce cache can accept the request
- **AND** a repeated request with the same nonce is rejected
