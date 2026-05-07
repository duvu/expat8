## Context

The backend currently logs mostly startup information and ad-hoc warning/error lines from specific modules. During production incidents, operators cannot reliably correlate failures across API handler, database access, and LiteLLM calls because request-scoped identifiers are not consistently propagated. The system already runs in Docker and relies on stdout log collection, so the design must preserve simple container-friendly output while making logs machine-parseable and diagnostically useful.

## Goals / Non-Goals

**Goals:**
- Introduce a single structured logger contract across backend modules.
- Ensure every request has a correlation identifier (`request_id`) that appears in all relevant logs.
- Standardize error logging so validation, dependency, and unhandled failures contain actionable metadata.
- Add configuration for log verbosity and redaction of sensitive fields before output.
- Keep operational compatibility with current Docker log collection and existing runtime behavior.

**Non-Goals:**
- Building a dedicated log storage UI or observability platform in this change.
- Changing endpoint response payload contracts solely for logging purposes.
- Replacing all business logic; this change focuses on observability instrumentation.

## Decisions

1. Structured JSON logging for all backend log events.
- Rationale: JSON logs support easy parsing/filtering in container pipelines and avoid fragile free-text parsing.
- Alternative considered: plain-text formatted logs with prefixes. Rejected due to weak machine readability and inconsistent fields.

2. Request context propagation via middleware + logger child context.
- Rationale: generate or accept a request ID at ingress, attach to request scope, and reuse in downstream logging for end-to-end traceability.
- Alternative considered: recomputing correlation IDs in each module. Rejected because it fragments traces and increases implementation errors.

3. Centralized logger utility module with level gating and redaction.
- Rationale: one module enforces schema, redaction, and level filtering uniformly.
- Alternative considered: direct `console.*` wrappers in each file. Rejected because policy drift would quickly appear.

4. Explicit error classification at API boundary.
- Rationale: map known error classes (validation, auth/session, dependency timeouts, DB failures, unexpected) to deterministic log events with structured metadata.
- Alternative considered: only logging stack traces in catch-all handler. Rejected because it misses business context and complicates triage.

5. Incremental rollout with compatibility mode.
- Rationale: keep existing behavior while replacing internals behind stable interfaces, minimizing deploy risk.
- Alternative considered: big-bang refactor of all modules at once. Rejected due to elevated regression risk.

## Risks / Trade-offs

- [Risk] Increased log volume from request lifecycle events → Mitigation: level-based sampling/gating and concise field sets for info logs.
- [Risk] Sensitive data leakage in structured context fields → Mitigation: default deny-list redaction for secrets/tokens/passwords and test coverage for redaction paths.
- [Risk] Missing request context in async/background code paths → Mitigation: pass logger/context explicitly across module boundaries and add tests for propagation.
- [Risk] Performance overhead from serialization on hot paths → Mitigation: keep payloads small, avoid deep object logging, and gate debug-level events.

## Migration Plan

1. Add logger utility and request-context middleware without removing existing behavior.
2. Instrument API entry/exit and error boundary first.
3. Instrument high-value modules (Postgres word store, generation service, auth/session verification).
4. Enable config defaults (`LOG_LEVEL=info`, redaction enabled) and deploy.
5. Verify logs in production with correlation-based trace checks and adjust verbosity if needed.

Rollback strategy:
- Revert to previous image tag if error rate increases.
- Set `LOG_LEVEL=error` as immediate mitigation to reduce noise while preserving critical diagnostics.

## Open Questions

- Should response headers expose `X-Request-Id` for client-side support tooling, or keep request IDs server-internal only?
- Do we need environment-specific log level defaults (e.g., debug in staging, info in production) in deployment compose now or later?
- Should dependency latency (DB/LiteLLM timing) be logged at info level by default, or only at debug level?
