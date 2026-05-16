## MODIFIED Requirements

### Requirement: Exam result sync is asynchronous and retryable
The mobile app SHALL synchronize locally stored exam results to the backend in the background and retry failed sync attempts without blocking the user. When the backend returns a server-confirmed result with a certificate ID, the mobile app SHALL keep the certificate action viewable from the results screen with all required API dependencies available.

#### Scenario: Background sync succeeds
- **WHEN** the sync worker uploads a locally stored exam result successfully
- **THEN** the app marks the local record as synced

#### Scenario: Background sync fails
- **WHEN** a locally stored exam result cannot be uploaded
- **THEN** the app keeps the record locally and retries later

#### Scenario: User can continue after result capture
- **WHEN** exam completion has been captured locally but sync has not finished
- **THEN** the user can continue using the app without waiting for backend sync

#### Scenario: Server-confirmed certificate remains viewable
- **WHEN** the backend returns a passing exam result with a certificate ID
- **THEN** the results screen exposes `View Certificate` and opens the certificate view without a missing API client error
