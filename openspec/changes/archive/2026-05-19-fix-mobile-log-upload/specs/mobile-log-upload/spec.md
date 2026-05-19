## ADDED Requirements

### Requirement: Mobile app uploads sanitized log archives
The mobile app SHALL allow a user to upload matching sanitized diagnostic logs to the backend as a log archive using app credential signing.

#### Scenario: User uploads matching logs
- **WHEN** the user triggers send-to-server from the mobile log viewer and matching persisted logs exist
- **THEN** the app uploads a sanitized UTF-8 log archive to `POST /v1/mobile/log-archives` with app credential headers, device metadata, filename metadata, and optional bearer session token

#### Scenario: No logs match selected filters
- **WHEN** the user triggers send-to-server and no persisted logs match the selected filters
- **THEN** the app does not call the backend and shows visible feedback that there are no logs to send

#### Scenario: Upload fails
- **WHEN** the backend rejects the upload, the request times out, or the network request fails
- **THEN** the app shows visible failure feedback and preserves the local logs for later retry or export

### Requirement: Backend accepts signed mobile log archive uploads
The backend SHALL accept signed non-JSON mobile log archive uploads, persist the exact uploaded content, and return archive metadata.

#### Scenario: Signed text archive upload succeeds
- **WHEN** `POST /v1/mobile/log-archives` receives a non-empty `text/plain` request with valid app credential signature and mobile log metadata headers
- **THEN** the backend stores the raw uploaded bytes as a log archive and responds `201` with archive metadata including ID, filename, content type, size, source app ID, source device ID, source label, upload timestamp, and retention metadata

#### Scenario: Missing app credentials
- **WHEN** `POST /v1/mobile/log-archives` receives a request without required app credential headers
- **THEN** the backend rejects the upload with `400` and does not store an archive

#### Scenario: Empty archive body
- **WHEN** `POST /v1/mobile/log-archives` receives a signed request with an empty body
- **THEN** the backend rejects the upload with `400` and does not store an archive

#### Scenario: Optional user session is valid
- **WHEN** the upload includes a valid bearer session token
- **THEN** the backend associates the archive metadata with the matching user ID

#### Scenario: Optional user session is invalid
- **WHEN** the upload includes an invalid bearer session token
- **THEN** the backend rejects the upload and does not store an archive

### Requirement: Admin users retrieve uploaded mobile log archives
The backend SHALL expose uploaded mobile log archives through admin log archive APIs for support investigation.

#### Scenario: Uploaded archive appears in list
- **WHEN** an admin lists log archives after a successful mobile upload
- **THEN** the uploaded archive appears with metadata and content/download URLs

#### Scenario: Admin reads uploaded content
- **WHEN** an admin requests the content endpoint for an uploaded archive
- **THEN** the backend returns the exact uploaded sanitized log archive content

#### Scenario: Admin downloads uploaded content
- **WHEN** an admin requests the download endpoint for an uploaded archive
- **THEN** the backend returns the exact uploaded sanitized log archive content as an attachment
