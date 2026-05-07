## ADDED Requirements

### Requirement: PostgreSQL registration maps duplicate identifiers consistently
The backend SHALL map PostgreSQL duplicate user identifier conflicts to the public duplicate-registration API contract even when the conflict is detected by a database constraint.

#### Scenario: Duplicate identifier is detected before insert
- **WHEN** a registration request uses an identifier that already exists in PostgreSQL
- **THEN** the backend returns `409` with `{ "error": "user_exists" }`

#### Scenario: Concurrent duplicate registration hits unique constraint
- **WHEN** two registration requests for the same normalized identifier race and PostgreSQL reports unique violation `23505`
- **THEN** the backend returns `409` with `{ "error": "user_exists" }` instead of `500 internal_error`

#### Scenario: Different database error occurs during registration
- **WHEN** PostgreSQL returns a non-duplicate persistence error while registering a user
- **THEN** the backend does not mask the error as `user_exists`

### Requirement: Registration input validation is distinct from sign-in credentials
The backend SHALL distinguish invalid registration input from invalid sign-in credentials in internal error handling while preserving the public response contract.

#### Scenario: Registration input is invalid
- **WHEN** registration input is missing an identifier or has a password shorter than the accepted minimum
- **THEN** the backend returns `400` with `{ "error": "bad_request" }`

#### Scenario: Sign-in credentials are invalid
- **WHEN** sign-in uses an unknown identifier or wrong password
- **THEN** the backend returns `401` with `{ "error": "invalid_credentials" }`

#### Scenario: Invalid registration input is logged or inspected
- **WHEN** developers inspect the registration validation failure path
- **THEN** the internal error type identifies invalid input rather than invalid sign-in credentials
