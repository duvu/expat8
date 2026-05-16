## Why

Tapping `Take Exam` currently fails late when the backend cannot be reached, leaving the user with a generic start-exam failure and no clear recovery path. We already expose a backend readiness probe, so the exam entry flow should use it to avoid a dead-end start attempt and make backend outages obvious.

## What Changes

- Add a backend-readiness preflight before the mobile exam flow attempts `POST /v1/exam/start`.
- Show a specific retryable error when the backend is unreachable or unhealthy instead of the generic `Failed to start exam` message.
- Keep the existing exam session, question, and results flow unchanged when the backend is healthy.
- Reuse the existing `/health/ready` endpoint rather than adding a new backend route.

## Capabilities

### New Capabilities
- `mobile-exam-backend-availability`: the mobile exam entry flow checks backend readiness before starting an exam, fails fast with a retryable error when the backend is unavailable, and only navigates into the exam when the backend can be reached.

### Modified Capabilities

## Impact

- Mobile exam entry path and startup error handling
- Mobile backend API client
- Mobile exam controller tests and widget tests
- No backend schema or exam payload changes
