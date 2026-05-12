## Purpose
Define that completed exam results are persisted locally before backend synchronisation.

## ADDED Requirements

### Requirement: Exam results are stored locally before backend sync
The mobile app SHALL persist a completed exam result locally before attempting backend synchronization.

#### Scenario: Exam completes while backend is slow
- **WHEN** the user finishes an exam and the backend response is delayed
- **THEN** the app stores the exam result locally first and keeps the completion flow responsive

#### Scenario: Exam completes while offline
- **WHEN** the user finishes an exam without network connectivity
- **THEN** the app stores the exam result locally and queues it for later sync

### Requirement: Exam result sync is asynchronous and retryable
The mobile app SHALL synchronize locally stored exam results to the backend in the background and retry failed sync attempts without blocking the user.

#### Scenario: Background sync succeeds
- **WHEN** the sync worker uploads a locally stored exam result successfully
- **THEN** the app marks the local record as synced

#### Scenario: Background sync fails
- **WHEN** a locally stored exam result cannot be uploaded
- **THEN** the app keeps the record locally and retries later

#### Scenario: User can continue after result capture
- **WHEN** exam completion has been captured locally but sync has not finished
- **THEN** the user can continue using the app without waiting for backend sync

### Requirement: Exam result sync is idempotent
The backend SHALL accept repeated exam result sync attempts for the same local attempt without creating duplicate exam records.

#### Scenario: Duplicate sync request arrives
- **WHEN** the backend receives the same exam result more than once
- **THEN** it stores only one canonical attempt record and returns a successful idempotent response
