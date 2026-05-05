## ADDED Requirements

### Requirement: Backend emits structured logs with a stable schema
The backend SHALL emit runtime logs in structured JSON format with mandatory fields `timestamp`, `level`, `event`, and `component`, plus optional contextual fields.

#### Scenario: API request is processed
- **WHEN** an HTTP request enters and exits the backend
- **THEN** the backend emits structured lifecycle logs that include method, path, status, and elapsed time

#### Scenario: Background generation task logs activity
- **WHEN** the vocabulary scheduler or generation service executes a generation attempt
- **THEN** the backend emits structured logs for start, result, and failure states with mode and count metadata

### Requirement: Backend propagates request correlation identifiers
The backend MUST attach a request correlation identifier to each incoming request and include it in all logs produced for that request scope.

#### Scenario: Client does not provide correlation ID
- **WHEN** a request arrives without an external correlation header
- **THEN** the backend generates a new request identifier and uses it for all request-scoped logs

#### Scenario: Error occurs during a request
- **WHEN** any handler or dependency call fails while serving a request
- **THEN** the emitted error logs include the same request identifier as the request lifecycle logs

### Requirement: Backend redacts sensitive values before logging
The backend MUST sanitize or redact sensitive fields before writing logs.

#### Scenario: Structured context includes secret field
- **WHEN** log metadata includes fields such as password, token, app secret, or authorization header
- **THEN** the backend replaces sensitive values with redacted placeholders before emission

#### Scenario: Error message includes sensitive payload
- **WHEN** an exception message or dependency payload contains sensitive patterns
- **THEN** the backend emits a sanitized message that excludes the raw sensitive value

### Requirement: Backend supports configurable log level policy
The backend SHALL support environment-driven log level configuration that controls which log events are emitted.

#### Scenario: Production uses info level
- **WHEN** log level is configured as `info`
- **THEN** debug-level events are suppressed while info, warn, and error events remain emitted

#### Scenario: Incident diagnosis requires verbose logs
- **WHEN** operators temporarily set log level to `debug`
- **THEN** request and dependency diagnostic events are emitted without code changes
