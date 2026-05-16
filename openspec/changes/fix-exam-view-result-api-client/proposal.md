## Why

After a learner completes and passes an exam, tapping `View Certificate` opens a certificate screen that cannot fetch data because no `BackendApiClient` is provided, showing `API client not available.` instead of the result certificate. This breaks the exam completion path after a successful result and indicates an inconsistent dependency-passing pattern in the mobile exam flow.

## What Changes

- Ensure the mobile exam results flow passes a usable `BackendApiClient` into the certificate/result view opened by `View Certificate`.
- Keep the results screen and certificate screen dependency model consistent with the rest of the mobile app instead of relying on nullable API client state.
- Add focused widget/unit coverage that reproduces the `View Certificate` path and verifies no `API client not available` error is shown when a certificate ID is present.
- Review adjacent exam navigation/result screens for consistency so result actions (`View Certificate`, `Done`, retry paths) do not depend on missing clients or stale route state.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `mobile-exam-navigation`: results actions must preserve required runtime dependencies when navigating from exam results to certificate/result detail screens.
- `exam-result-sync`: completed exam results and generated certificates must remain viewable after result capture without being blocked by backend sync or missing API client wiring.

## Impact

- Mobile Flutter exam UI: `mobile/lib/src/exam/exam_results_screen.dart`, `mobile/lib/src/exam/exam_certificate_screen.dart`, and associated route construction.
- Mobile test coverage for the passed-exam `View Certificate` flow and certificate API loading behavior.
- No backend API contract change is expected; this is a mobile dependency wiring and consistency fix.
