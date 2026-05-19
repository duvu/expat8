## 1. Reproduce And Diagnose

- [x] 1.1 Run existing backend log archive tests and mobile log upload tests to establish the current baseline.
- [x] 1.2 Reproduce the failing upload path with a mobile-equivalent signed `POST /v1/mobile/log-archives` request against a local backend.
- [x] 1.3 Identify whether the failure is caused by mobile signing/body encoding, backend raw-body/signature validation, session handling, archive storage, configuration, or network URL selection.

## 2. Backend Fixes

- [x] 2.1 Fix backend request handling if signed non-JSON mobile log archive uploads are rejected or stored incorrectly.
- [x] 2.2 Add backend coverage for successful signed text upload, missing credentials, empty body rejection, invalid optional session rejection, and admin list/content/download retrieval.
- [x] 2.3 Update `contracts/api.md` to document `POST /v1/mobile/log-archives` if the contract is missing or stale.

## 3. Mobile Fixes

- [x] 3.1 Fix mobile upload request generation if the client signs different bytes than it sends, omits required metadata, uses the wrong URL, or mishandles server errors.
- [x] 3.2 Add or tighten mobile tests for `BackendApiClient.uploadLogArchive` so headers, body, signature input, session token, and failure behavior are covered.
- [x] 3.3 Add or tighten repository/UI tests so empty log selections skip upload, sanitized payloads are uploaded, and failed uploads show visible feedback without deleting local logs.

## 4. End-To-End Verification

- [x] 4.1 Run backend test suite with `cd backend && npm test`.
- [x] 4.2 Run targeted mobile tests covering log upload and log viewer behavior.
- [x] 4.3 Perform an end-to-end smoke test: upload a mobile-style signed sanitized log archive, confirm `201`, list it via admin API, retrieve content, and verify the content matches.
- [x] 4.4 Document the verified root cause, fix, and smoke-test result in the implementation notes or final response.
