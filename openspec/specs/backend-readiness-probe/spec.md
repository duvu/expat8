## ADDED Requirements

### Requirement: Backend exposes a DB-aware readiness probe
The system SHALL expose `GET /health/ready` that checks database connectivity before reporting healthy. The endpoint requires no authentication and is exempt from app credential headers.

#### Scenario: Database is reachable — probe returns healthy
- **WHEN** `GET /health/ready` is called and the DB pool can execute `SELECT 1`
- **THEN** the response is `200 { "ok": true, "db": "ok" }`

#### Scenario: Database is unreachable — probe returns unhealthy
- **WHEN** `GET /health/ready` is called and the DB query fails or times out
- **THEN** the response is `503 { "ok": false, "db": "error" }`

#### Scenario: Probe is exempt from app credentials
- **WHEN** `GET /health/ready` is called without any `X-Expat8-*` headers
- **THEN** the request is NOT rejected with `400 bad_request`

#### Scenario: Probe returns x-request-id header
- **WHEN** `GET /health/ready` is called
- **THEN** the response includes an `x-request-id` header for log correlation
