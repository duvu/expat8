## Purpose
Define the authenticated endpoint that returns the current user's non-sensitive profile fields.

## Requirements

### Requirement: Authenticated user can fetch own profile
The system SHALL expose `GET /v1/me` that returns the current user's non-sensitive profile fields when called with a valid Bearer session token.

#### Scenario: Valid session returns profile
- **WHEN** a request is made to `GET /v1/me` with `Authorization: Bearer <valid_token>`
- **THEN** the response is `200` with `{ user_id, identifier, display_name }`

#### Scenario: Missing or invalid session returns 401
- **WHEN** a request is made to `GET /v1/me` with no `Authorization` header or an invalid token
- **THEN** the response is `401 { "error": "invalid_session" }`

#### Scenario: Response does not expose sensitive fields
- **WHEN** `GET /v1/me` returns a profile
- **THEN** the response body SHALL NOT contain `password_hash`, `token_hash`, or any session credential
