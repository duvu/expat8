## Why

Backend incidents are currently hard to diagnose quickly because logs are sparse, inconsistent across modules, and missing request-level context. We need robust, structured tracing now to reduce time-to-detect and time-to-recover for production failures.

## What Changes

- Introduce structured backend logging with consistent fields (timestamp, level, event, request_id, route, component, error metadata).
- Add request-scoped tracing so all logs emitted during one request share a stable correlation ID.
- Standardize error logging for validation errors, dependency failures (Postgres/LiteLLM), and unexpected exceptions.
- Add configuration controls for log level and optional payload redaction to avoid leaking sensitive content.
- Add tests that verify logging behavior and traceability for critical API flows.

## Capabilities

### New Capabilities
- `backend-error-tracing-logging`: Structured, request-correlated logging and error tracing requirements for the backend runtime and API handlers.

### Modified Capabilities
- `backend-word-feed-sync`: Clarify observable error behavior for feed/sync failures with traceable request identifiers in logs.

## Impact

- Affected code: backend runtime bootstrap, API middleware/handlers, generation service, Postgres integration points.
- Affected operations: production diagnostics, incident triage, and alert correlation.
- API impact: no breaking endpoint contract changes expected; improved observability semantics only.
- Dependencies: no required external logging platform, but output must remain compatible with container log collectors.
