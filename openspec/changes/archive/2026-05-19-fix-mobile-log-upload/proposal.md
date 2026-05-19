## Why

Mobile support log upload is present in the app UI but is not working reliably end-to-end, leaving support teams without device logs when reproducing production issues is hard.

This change restores a verified path for sending sanitized mobile logs to the server and retrieving them from the admin-side log archive APIs.

## What Changes

- Investigate the mobile-to-backend log upload flow, including mobile signing, raw-body handling, backend archive persistence, and admin retrieval.
- Fix the defect that prevents sanitized mobile log archives from reaching server storage.
- Add or adjust tests so signed non-JSON log archive uploads are covered on the backend and the mobile upload client behavior is covered locally.
- Verify end-to-end that a mobile-style signed upload returns `201`, is persisted, appears in admin archive listing, and its content can be retrieved.

## Capabilities

### New Capabilities
- `mobile-log-upload`: Defines the end-to-end behavior for uploading sanitized mobile diagnostic log archives to the backend and making them retrievable through admin log archive APIs.

### Modified Capabilities

None.

## Impact

- Mobile: log viewer send-to-server action, `WordRepository.sendLogsToServer`, and `BackendApiClient.uploadLogArchive`.
- Backend: `POST /v1/mobile/log-archives`, app credential signing/raw-body middleware, file log archive storage, and admin log archive routes.
- Contracts/tests: API documentation and automated coverage for mobile log archive upload and retrieval.
