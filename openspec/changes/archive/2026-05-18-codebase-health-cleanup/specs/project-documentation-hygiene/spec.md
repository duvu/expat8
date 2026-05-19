## MODIFIED Requirements

### Requirement: Current documentation matches the live codebase
The project SHALL keep current-facing markdown documentation aligned with the implemented storage layer, API endpoints, mobile data-loading flow, and security requirements. This includes ensuring all actively-used API endpoints are documented in `contracts/api.md`.

#### Scenario: Current docs describe mobile storage
- **WHEN** a current-facing document describes the mobile local persistence layer
- **THEN** it MUST describe ObjectBox as the source of truth and MUST NOT present SQLite or sqflite as the active implementation

#### Scenario: Current docs describe card loading
- **WHEN** a current-facing document describes backend card loading or vocabulary refill
- **THEN** it MUST describe signed `POST /v1/learning/cards` requests and MUST NOT present `/v1/words/next` or `GET /v1/learning/cards` as supported active behavior

#### Scenario: Current docs describe mobile refresh internals
- **WHEN** a current-facing document describes mobile prefetch, refresh, or sync internals
- **THEN** it MUST use names and flows that exist in the current mobile codebase and MUST NOT reference removed workers or deleted repository methods as active components

#### Scenario: Admin endpoints used by dashboard are documented
- **WHEN** the dashboard calls an admin API endpoint
- **THEN** that endpoint MUST be documented in `contracts/api.md` with request/response format and auth requirements
