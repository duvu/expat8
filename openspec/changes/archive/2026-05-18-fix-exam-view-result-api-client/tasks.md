## 1. Reproduce and Audit

- [x] 1.1 Reproduce or confirm the failure path where tapping `View Certificate` after a passed exam opens `ExamCertificateScreen` without an API client and shows `API client not available.`
- [x] 1.2 Audit mobile exam route construction (`LearningScreen`, `ExamQuestionScreen`, `ExamResultsScreen`, `ExamCertificateScreen`) for missing dependency propagation and stale route assumptions.
- [x] 1.3 Search for other `ExamCertificateScreen` construction sites and confirm each either passes a usable API client or intentionally handles a non-exam entry point.

## 2. Implementation

- [x] 2.1 Add a read-only `apiClient` getter to `ExamSessionController` so exam result routes can reuse the controller-owned backend client.
- [x] 2.2 Update `ExamResultsScreen` so the `View Certificate` button constructs `ExamCertificateScreen` with `apiClient: widget.controller.apiClient`.
- [x] 2.3 Keep `ExamCertificateScreen` error handling for genuinely missing clients, but ensure the normal passed-exam result path never reaches that state.
- [x] 2.4 Review result actions (`View Certificate`, `Take Again`, `Done`, timeout retry) for consistent route behavior and no accidental extra pops or missing resets.

## 3. Tests

- [x] 3.1 Add a focused widget test for a passed exam result with `certificateId` where tapping `View Certificate` opens the certificate view without rendering `API client not available.`
- [x] 3.2 Add or update certificate screen coverage to verify it calls `fetchExamCertificate` through the supplied `BackendApiClient` and renders certificate content on success.
- [x] 3.3 Add or update a negative coverage case only if needed to preserve the explicit missing-client error for non-exam/manual construction.

## 4. Verification

- [x] 4.1 Run the focused mobile exam/certificate tests.
- [x] 4.2 Run `cd mobile && flutter test`.
- [x] 4.3 Manually verify the passed-exam flow on device/emulator: complete an exam, tap `View Certificate`, confirm no `API client not available` error and certificate content loads.
