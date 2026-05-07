## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns new vocabulary items for the mobile app and MUST emit traceable error logs when feed processing fails.

#### Scenario: Mobile requests a new word
- **WHEN** the mobile app calls the new-word feed endpoint with source language, target language, mode, and limit
- **THEN** the backend returns vocabulary items matching the request parameters

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a new-word request
- **THEN** the backend can return stored words without calling AI generation

#### Scenario: Feed request fails due to dependency error
- **WHEN** the backend cannot complete new-word retrieval because a dependency call fails
- **THEN** the backend emits an error log containing request correlation ID, dependency name, and failure reason

## ADDED Requirements

### Requirement: Backend traces study-event sync failures with correlation context
The backend MUST produce structured error logs for study-event sync failures with sufficient correlation and validation metadata for incident triage.

#### Scenario: Sync payload validation fails
- **WHEN** the mobile app sends a malformed study-event sync request
- **THEN** the backend emits a warning/error log with request correlation ID and validation error category

#### Scenario: Sync persistence fails
- **WHEN** writing sync events to persistence fails unexpectedly
- **THEN** the backend emits an error log with request correlation ID, operation name, and failure details
