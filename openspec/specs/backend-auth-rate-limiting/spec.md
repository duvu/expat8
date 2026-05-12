# backend-auth-rate-limiting Specification

## Purpose
TBD - created by archiving change fix-codebase-review-issues. Update Purpose after archive.
## Requirements
### Requirement: Backend enforces rate limiting on registration endpoint
The backend SHALL reject excessive registration attempts from a single IP address within a time window.

#### Scenario: Client exceeds registration rate limit
- **WHEN** a client sends more than 10 registration requests within a 15-minute window from the same IP
- **THEN** the backend returns `429 Too Many Requests` with `{ "error": "too_many_requests" }`

#### Scenario: Client is within registration rate limit
- **WHEN** a client sends 10 or fewer registration requests within a 15-minute window from the same IP
- **THEN** the backend processes each registration normally

### Requirement: Backend enforces rate limiting on sign-in endpoint
The backend SHALL reject excessive sign-in attempts from a single IP address within a time window.

#### Scenario: Client exceeds sign-in rate limit
- **WHEN** a client sends more than 20 sign-in requests within a 15-minute window from the same IP
- **THEN** the backend returns `429 Too Many Requests` with `{ "error": "too_many_requests" }`

#### Scenario: Client is within sign-in rate limit
- **WHEN** a client sends 20 or fewer sign-in requests within a 15-minute window from the same IP
- **THEN** the backend processes each sign-in normally

### Requirement: Rate limiting state is per-IP and resets on window expiry
The backend SHALL track rate limit counts per client IP and SHALL reset counts after the window expires.

#### Scenario: Rate limit window expires
- **WHEN** the 15-minute window passes after the first request
- **THEN** the request counter resets and the client can send requests again

#### Scenario: Different IPs have independent counters
- **WHEN** two clients from different IPs send requests to the same endpoint
- **THEN** each IP's counter is tracked independently

