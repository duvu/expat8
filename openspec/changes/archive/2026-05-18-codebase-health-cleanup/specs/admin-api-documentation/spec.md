## ADDED Requirements

### Requirement: All admin API endpoints are documented in contracts/api.md
The `contracts/api.md` file SHALL document every admin endpoint that the dashboard or any client actively calls, following the same format as existing endpoint documentation.

#### Scenario: Article creation endpoint is documented
- **WHEN** a developer looks for the `POST /v1/admin/articles` contract
- **THEN** `contracts/api.md` documents the request body, response shape, and error codes

#### Scenario: Article publish endpoint is documented
- **WHEN** a developer looks for the `POST /v1/admin/articles/:id/publish` contract
- **THEN** `contracts/api.md` documents the expected behavior, response, and error codes

#### Scenario: Article reprocess endpoint is documented
- **WHEN** a developer looks for the `POST /v1/admin/articles/:id/reprocess` contract
- **THEN** `contracts/api.md` documents the expected behavior and response

#### Scenario: Vocabulary review endpoint is documented
- **WHEN** a developer looks for the `PATCH /v1/admin/vocabulary/:id` contract
- **THEN** `contracts/api.md` documents the request body (status field), response, and error codes

#### Scenario: Log archive endpoints are documented
- **WHEN** a developer looks for log archive admin API contracts
- **THEN** `contracts/api.md` documents `GET /v1/admin/log-archives`, `GET /v1/admin/log-archives/:id`, and `GET /v1/admin/log-archives/:id/content` with their responses

### Requirement: Admin endpoint documentation includes auth requirements
Each documented admin endpoint SHALL specify that it requires both app-credential HMAC headers and a valid admin API token.

#### Scenario: Admin endpoint auth is documented
- **WHEN** reading any admin endpoint documentation
- **THEN** it states that the `Authorization` header with admin token is required in addition to app-credential headers, and that missing/invalid token returns 403
