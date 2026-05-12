# mobile-app-credential-signing Specification

## Purpose
TBD - created by archiving change resolve-codebase-consistency-drift. Update Purpose after archive.
## Requirements
### Requirement: Mobile signs `/v1/*` requests using the backend credential contract
The mobile app SHALL generate app credential headers for `/v1/*` requests using the same canonical request structure verified by the backend.

#### Scenario: Mobile sends a signed GET request
- **WHEN** the mobile app sends a signed GET request with query parameters
- **THEN** it signs the upper-case method, sorted path and query, timestamp, nonce, and empty-body content hash using the configured app secret

#### Scenario: Mobile sends a signed JSON request
- **WHEN** the mobile app sends a signed POST or PUT request with a JSON body
- **THEN** it signs the exact UTF-8 request body bytes used as the transmitted body

#### Scenario: User session is present
- **WHEN** the mobile app sends a signed request with a user session
- **THEN** it includes the bearer session token while preserving the app credential signature required for `/v1/*`

### Requirement: Mobile credential nonces are random and unique within the replay window
The mobile app MUST generate a high-entropy nonce for every signed request and MUST NOT derive credential nonces solely from timestamps or counters.

#### Scenario: Concurrent requests are signed
- **WHEN** the mobile app signs multiple requests in the same clock tick or microsecond
- **THEN** each request receives a distinct random nonce

#### Scenario: Backend replay protection is active
- **WHEN** the backend rejects repeated nonces within the replay window
- **THEN** normal mobile request concurrency does not reuse a nonce and trigger false replay rejection

