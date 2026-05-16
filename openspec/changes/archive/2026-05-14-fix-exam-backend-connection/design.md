## Context

The mobile exam flow currently starts an exam session only after the user taps `Take Exam`. When the backend is unreachable, the controller falls through to a generic start-exam failure after the backend call fails, which looks like a dead end from the user's perspective.

The backend already exposes an unauthenticated `GET /health/ready` endpoint. That makes the exam entry path a good candidate for a lightweight preflight check before attempting the authenticated exam-start request.

## Goals / Non-Goals

**Goals:**
- Detect backend unavailability before the app enters the exam flow
- Show a retryable, exam-specific connectivity error instead of a generic failure
- Keep the healthy-path exam session behavior unchanged
- Avoid backend schema, payload, or scoring changes

**Non-Goals:**
- Offline exam mode
- New exam questions or scoring logic
- Changes to learning cards, review flow, or navigation outside the exam entry path
- Backend route or database changes

## Decisions

### D1: Preflight the existing readiness probe before `POST /v1/exam/start`
The exam entry path should call `GET /health/ready` first and only proceed to `POST /v1/exam/start` when the backend reports healthy.

**Why:** The probe already exists, does not require app credentials, and lets the app distinguish backend outages from exam-start validation failures.

**Alternatives considered:**
- Call `POST /v1/exam/start` directly and rely on its failure: simpler, but it keeps the user on a generic failure path and makes backend outages harder to identify.
- Add a new backend endpoint for exam-specific health: unnecessary because the existing readiness probe already answers the availability question.

### D2: Keep the readiness check inside `ExamSessionController`
The controller should own the preflight and the exam-start request because it already owns the backend client and manages exam state transitions.

**Why:** This keeps the UI thin and avoids spreading availability logic across the learning screen and exam screens.

**Alternatives considered:**
- Put the preflight in `LearningScreen`: works, but mixes UI orchestration with backend state handling and makes the controller harder to reason about.

### D3: Surface one retryable connectivity error for probe and network failures
If the readiness probe fails, or if the subsequent exam-start request fails because the backend becomes unreachable, the controller should keep the user out of the exam flow and surface one clear retryable message.

**Why:** From the user's perspective both cases are the same problem: the exam cannot start because the backend is unavailable.

**Alternatives considered:**
- Different messages for probe failure vs start failure: more precise, but it adds copy complexity without improving the recovery path.

### D4: Preserve existing exam validation errors
`INSUFFICIENT_WORDS` and other backend validation errors should keep their current messages and should not be collapsed into the new connectivity error.

**Why:** Availability problems and business-rule failures are different problems and should remain distinguishable.

## Risks / Trade-offs

- [Extra network round trip on exam entry] → Keep the probe lightweight and only run it when the user explicitly starts an exam.
- [Backend may fail after readiness succeeds] → Keep the existing `POST /v1/exam/start` failure handling so the same retryable message covers both stages.
- [Over-classifying validation errors as connectivity errors] → Preserve current `BackendApiException` handling for known exam validation cases.
- [Probe adds a small delay on slow networks] → Use the shortest practical timeout and keep the current `ExamState.loading` UI so the user sees immediate feedback.

## Migration Plan

1. Add a backend-readiness method to the mobile API client.
2. Update the exam session controller to run the readiness probe before starting an exam.
3. Update the entry UI to keep the user on the exam entry surface and show a retryable connectivity message when readiness or start fails.
4. Add focused tests for healthy, unavailable, and retry paths.
5. Release the mobile build. No backend migration is required.

Rollback: remove the readiness preflight and return to the current direct `POST /v1/exam/start` flow if the probe introduces an unexpected regression.

## Open Questions

None.
