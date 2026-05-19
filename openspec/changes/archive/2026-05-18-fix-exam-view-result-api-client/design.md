## Context

The mobile exam flow constructs an `ExamSessionController` with a `BackendApiClient` in `LearningScreen`, pushes `ExamQuestionScreen`, then replaces it with `ExamResultsScreen` after the final answer is submitted. When the user passes, `ExamResultsScreen` renders `View Certificate`; that action currently pushes `ExamCertificateScreen(certificateId: certId)` without passing the API client. `ExamCertificateScreen` treats a missing client as fatal and renders `API client not available.`.

The backend certificate endpoint and mobile API client already exist, so the issue is local dependency propagation and route consistency rather than an API contract gap.

## Goals / Non-Goals

**Goals:**

- Ensure `View Certificate` from exam results opens a certificate screen with a usable `BackendApiClient`.
- Keep exam route construction consistent from learning screen → question screen → results screen → certificate screen.
- Add focused tests that catch missing API client wiring in the result/certificate path.
- Review adjacent exam result actions for route/dependency consistency.

**Non-Goals:**

- Do not change backend exam, certificate, or auth API contracts.
- Do not redesign the exam scoring or local result sync model.
- Do not add global service locator state solely for this route.

## Decisions

1. Expose the existing `BackendApiClient` from `ExamSessionController` through a read-only getter and use it when opening `ExamCertificateScreen`.

   Rationale: the controller already owns the client for exam start/submit calls, and every exam result route already has the controller. This is the smallest change and avoids adding another constructor argument through `LearningScreen`, `ExamQuestionScreen`, and `ExamResultsScreen`.

   Alternative considered: add a required `apiClient` argument to every exam route constructor. This is explicit, but it widens multiple route constructors and duplicates a dependency already held by the controller.

2. Keep `ExamCertificateScreen.apiClient` nullable only where a non-exam entry point might be introduced later, but ensure the exam result path always supplies it.

   Rationale: the immediate bug is the exam result path. Removing nullability from the certificate screen would force a larger refactor for possible deep-link routes that are not currently implemented.

   Alternative considered: construct a fresh `BackendApiClient` inside `ExamCertificateScreen` from `AppConfig.fromEnvironment()`. This would hide dependencies inside the screen and be inconsistent with the rest of the mobile app's injected-client pattern.

3. Add widget coverage around the passed-result `View Certificate` button and certificate screen loading behavior.

   Rationale: the failure is UI-visible and route-driven, so tests should exercise tapping the actual button and verify the certificate screen does not render the missing-client error.

## Risks / Trade-offs

- The controller getter exposes a dependency that was previously private → Keep it read-only and use it only for route construction.
- A future deep-link certificate route could still pass `null` if not wired correctly → Preserve the explicit error state and cover the exam result route now.
- Tests may need small fake API client helpers because `BackendApiClient` is concrete → Use the existing test style in mobile tests and keep fakes focused on certificate fetching.
