## ADDED Requirements

### Requirement: Backend accepts release uploads from admin operators
The backend SHALL provide an admin-only API endpoint for uploading a new mobile release. The upload SHALL include the APK binary, a version code (integer), a version name (string), and a platform identifier. The backend SHALL persist both the binary file and the metadata.

#### Scenario: Admin uploads a new Android release
- **WHEN** an authenticated admin sends a multipart POST to the release upload endpoint with a valid APK file, version_code, version_name, and platform "android"
- **THEN** the backend stores the APK file on disk, persists the release metadata, and returns the created release record with its ID, version info, file size, and SHA-256 hash

#### Scenario: Upload rejected without admin token
- **WHEN** a request to the release upload endpoint lacks a valid admin API token
- **THEN** the backend returns 403 Forbidden

#### Scenario: Upload rejected with missing required fields
- **WHEN** an admin upload omits the version_code, version_name, platform, or file attachment
- **THEN** the backend returns 400 Bad Request with an error indicating the missing field

### Requirement: Backend enforces a 5-version retention cap per platform
The backend SHALL retain at most 5 release versions per platform. After a successful upload that causes the count to exceed 5, the backend SHALL delete the oldest releases (metadata and binary file) until exactly 5 remain.

#### Scenario: Sixth release triggers pruning
- **WHEN** an admin uploads a 6th release for platform "android" and 5 releases already exist
- **THEN** the backend deletes the oldest release (lowest version_code) so that exactly 5 remain after the upload completes

#### Scenario: Upload within cap does not prune
- **WHEN** an admin uploads a release and fewer than 5 releases exist for that platform
- **THEN** no existing releases are deleted

### Requirement: Backend serves the latest release metadata to authenticated app clients
The backend SHALL provide a public-facing endpoint (app-credential authenticated, no user session required) that returns metadata for the most recent release of a given platform.

#### Scenario: Mobile checks for latest Android version
- **WHEN** the mobile app sends a GET request with valid app credentials and query parameter platform=android
- **THEN** the backend returns the metadata of the release with the highest version_code for that platform, including version_code, version_name, file_size_bytes, sha256, and created_at

#### Scenario: No releases exist for platform
- **WHEN** the mobile app checks the latest release for a platform with no uploads
- **THEN** the backend returns a response indicating no release is available (e.g., null or empty object)

### Requirement: Backend serves APK binary download to authenticated app clients
The backend SHALL provide a download endpoint (app-credential authenticated, no user session required) that streams the APK binary for a specific release ID.

#### Scenario: Mobile downloads a release APK
- **WHEN** the mobile app sends a GET request with valid app credentials to the download endpoint for a valid release ID
- **THEN** the backend streams the APK file with appropriate content-type (application/vnd.android.package-archive) and content-length headers

#### Scenario: Download for unknown release ID
- **WHEN** a download request references a release ID that does not exist
- **THEN** the backend returns 404 Not Found

### Requirement: Admin can list and delete releases
The backend SHALL provide admin-only endpoints for listing all stored releases and deleting a specific release by ID.

#### Scenario: Admin lists all releases
- **WHEN** an authenticated admin sends a GET request to the admin releases endpoint
- **THEN** the backend returns all stored releases ordered by version_code descending, including metadata for each

#### Scenario: Admin deletes a specific release
- **WHEN** an authenticated admin sends a DELETE request for a specific release ID
- **THEN** the backend removes both the metadata and the binary file from storage and returns 204

#### Scenario: Delete for unknown release ID
- **WHEN** an admin sends a DELETE request for a release ID that does not exist
- **THEN** the backend returns 404 Not Found
