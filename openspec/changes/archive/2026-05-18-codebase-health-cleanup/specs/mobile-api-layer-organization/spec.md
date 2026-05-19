## ADDED Requirements

### Requirement: API response DTOs are defined in dedicated model files
The mobile API layer SHALL define response DTO classes in `lib/src/api/models/` directory, organized by domain.

#### Scenario: Finding exam response types
- **WHEN** a developer looks for `ExamSessionResponse` or `ExamQuestion` class definitions
- **THEN** they are found in `lib/src/api/models/exam_models.dart`

#### Scenario: Finding learning response types
- **WHEN** a developer looks for `LearningCardBatch` or `SyncResult` class definitions
- **THEN** they are found in `lib/src/api/models/learning_models.dart`

#### Scenario: BackendApiClient does not define DTO classes
- **WHEN** examining `backend_api_client.dart`
- **THEN** the file contains no class definitions other than `BackendApiClient` and `BackendApiException`

### Requirement: API client uses a shared request helper for common HTTP patterns
The `BackendApiClient` SHALL use a private `_request()` method that encapsulates the repeated pattern of stopwatch timing, timeout handling, request/response logging, and error checking.

#### Scenario: Endpoint method uses shared request helper
- **WHEN** examining any public endpoint method in `BackendApiClient`
- **THEN** it delegates HTTP execution to the shared `_request()` helper rather than implementing its own timing/logging/error handling inline

#### Scenario: Request helper handles timeout
- **WHEN** an HTTP request exceeds the configured timeout duration
- **THEN** the `_request()` helper throws a timeout exception with appropriate logging

### Requirement: Existing imports continue to work via barrel exports
The mobile API layer SHALL re-export all DTO classes from `backend_api_client.dart` so that existing import statements in the codebase and tests continue to resolve.

#### Scenario: Test file imports DTO from original path
- **WHEN** a test file imports `BackendApiClient` and uses `LearningCardBatch`
- **THEN** the import resolves successfully without path changes
