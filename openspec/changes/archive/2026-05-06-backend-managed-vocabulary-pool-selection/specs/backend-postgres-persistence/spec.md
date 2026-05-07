## ADDED Requirements

### Requirement: Backend persists generation scheduler state
The backend SHALL persist generation run metadata and scheduler ownership state needed to operate vocabulary generation safely.

#### Scenario: Generation run completes
- **WHEN** a scheduler generation attempt completes
- **THEN** PostgreSQL stores run metadata including language, mode, counts, timestamps, and error status

#### Scenario: Scheduler lock is acquired
- **WHEN** a backend instance starts generating vocabulary for a language
- **THEN** PostgreSQL prevents another active backend instance from owning the same language generation work

### Requirement: Backend persists active cache inventory
The backend SHALL persist mobile cache inventory for duplicate avoidance.

#### Scenario: Cache inventory is reported
- **WHEN** mobile reports cached server word IDs for a device
- **THEN** PostgreSQL stores the active inventory with device, optional user, word ID, and timestamps

#### Scenario: Cache inventory is replaced
- **WHEN** mobile reports a new full cache inventory for a device
- **THEN** PostgreSQL replaces stale inventory rows for that device with the latest valid word IDs

### Requirement: Backend supports latest learner word state queries
The backend SHALL provide efficient persistence for latest per-learner word state used by card selection.

#### Scenario: Study event is accepted
- **WHEN** a study event is accepted for a learner and word
- **THEN** PostgreSQL upserts the latest learner word state for that learner and word

#### Scenario: Card selection excludes completed words
- **WHEN** the backend selects new cards for a learner
- **THEN** PostgreSQL can query completed or mastered word states without scanning the full study event log
