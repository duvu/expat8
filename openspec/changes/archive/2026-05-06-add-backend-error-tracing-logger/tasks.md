## 1. Logging Foundation

- [x] 1.1 Create a centralized backend logger module with JSON output, level filtering, and common field schema.
- [x] 1.2 Implement sensitive-field redaction helpers and unit tests for token/password/secret masking.
- [x] 1.3 Add environment config keys for log level and redaction behavior with safe production defaults.

## 2. Request Correlation and API Instrumentation

- [x] 2.1 Add request-context middleware that generates or accepts a correlation ID and attaches it to request scope.
- [x] 2.2 Instrument request lifecycle logs (request started/completed, status, latency, route metadata).
- [x] 2.3 Add global API error logging that captures request ID, error category, and sanitized details.

## 3. Domain and Dependency Trace Coverage

- [x] 3.1 Instrument Postgres word store operations with structured success/failure logs for critical write/read paths.
- [x] 3.2 Instrument generation service and LiteLLM client calls with request/scheduler context and failure reasons.
- [x] 3.3 Instrument study-event sync and word-feed failure paths to satisfy modified backend-word-feed-sync requirements.

## 4. Validation and Rollout

- [x] 4.1 Add backend tests verifying structured log shape, correlation propagation, and redaction behavior.
- [x] 4.2 Run backend test suite and update deployment configuration/docs for runtime log settings.
- [x] 4.3 Perform production verification checklist (request trace continuity and error observability) after deploy.
