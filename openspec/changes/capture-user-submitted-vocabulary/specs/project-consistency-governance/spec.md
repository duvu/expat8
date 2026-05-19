## MODIFIED Requirements

### Requirement: Cross-project API fields have an explicit lifecycle
Every API field, query parameter, header, and asynchronous status value used by mobile or backend SHALL be either implemented, reserved, or removed across code, contracts, tests, and docs.

#### Scenario: New API parameter is introduced
- **WHEN** a change adds a request field or query parameter
- **THEN** the contract documents it, backend validates or uses it, mobile sends it intentionally, and tests cover accepted and rejected values

#### Scenario: Existing API parameter is ignored
- **WHEN** a parameter is no longer read by the backend or no longer needed by mobile
- **THEN** the parameter is removed from mobile and current docs, or documented as reserved with tests proving the intended behavior

#### Scenario: New asynchronous submission status is introduced
- **WHEN** a change adds a mobile/backend status lifecycle such as queued, processing, ready, or failed for a cross-project resource
- **THEN** the status names, terminal/non-terminal meaning, and any associated response fields are documented in `contracts/api.md`, implemented in backend/mobile code, and covered by tests for each lifecycle branch
