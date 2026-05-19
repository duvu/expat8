## ADDED Requirements

### Requirement: Backend accepts uploaded log files from mobile
The backend SHALL provide an authenticated upload path for sanitized log files sent from the mobile app and SHALL persist each accepted upload as a server-side log archive file.

#### Scenario: Mobile uploads a log file
- **WHEN** the mobile app submits a sanitized log file through the authenticated upload path
- **THEN** the backend stores the file and records its metadata for dashboard browsing

#### Scenario: Unauthorized upload is rejected
- **WHEN** a request uploads logs without the required app credential headers
- **THEN** the backend rejects the upload and does not store the file

### Requirement: Backend enforces default log retention and size limits
The backend SHALL retain uploaded log archives for 3 days by default and SHALL cap total stored log archive volume at 100 MB by default.

#### Scenario: Log archive exceeds retention age
- **WHEN** an uploaded log archive is older than 3 days
- **THEN** the backend removes it during retention cleanup

#### Scenario: Log archive storage exceeds 100 MB
- **WHEN** the total stored log archive volume exceeds 100 MB
- **THEN** the backend evicts the oldest eligible log archives until storage is back under the limit

### Requirement: Backend exposes log archive metadata for dashboard browsing
The backend SHALL expose read-only metadata for stored log archives so the dashboard can list and inspect uploaded logs.

#### Scenario: Dashboard requests archive list
- **WHEN** the dashboard requests uploaded log archive metadata
- **THEN** the backend returns the archive list with upload time, size, retention status, and source metadata

#### Scenario: Dashboard requests a specific archive
- **WHEN** the dashboard requests a specific uploaded log archive
- **THEN** the backend returns the archive contents or a downloadable file reference
