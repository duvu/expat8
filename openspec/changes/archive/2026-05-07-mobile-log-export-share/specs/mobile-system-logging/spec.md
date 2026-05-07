## MODIFIED Requirements

### Requirement: Logs are persisted locally with retention and rotation
The mobile app MUST persist logs on-device and enforce a 60-minute retention limit plus a maximum record count to prevent unbounded storage growth and reduce diagnostic data exposure.

#### Scenario: Log retention age is exceeded
- **WHEN** persisted logs are older than 60 minutes
- **THEN** the app removes those log records during log pruning and preserves only records within the 60-minute window

#### Scenario: Log count threshold is exceeded
- **WHEN** persisted logs exceed the configured maximum record count
- **THEN** the app removes oldest log records and preserves newest records within the count limit

#### Scenario: App restarts after previous logging session
- **WHEN** the app restarts on the same device
- **THEN** previously persisted logs from the last 60 minutes remain queryable until removed by retention policy

### Requirement: Users can inspect and export logs on-device
The mobile app SHALL provide an in-app log viewer that supports filtering and exporting sanitized logs as a shareable text file through the device share sheet without requiring emulator attachment.

#### Scenario: User filters logs by severity
- **WHEN** the user selects a severity filter in the log viewer
- **THEN** the app displays only log entries matching the selected level range

#### Scenario: User exports logs for debugging
- **WHEN** the user triggers log export and matching logs exist
- **THEN** the app generates a UTF-8 text file containing sanitized persisted entries within the selected range and opens the platform share sheet with that file attached

#### Scenario: User exports logs when none match
- **WHEN** the user triggers log export and no persisted logs match the selected filters
- **THEN** the app shows visible feedback that there are no logs to export and does not open an empty share sheet

#### Scenario: Share action fails or is unavailable
- **WHEN** the generated log file cannot be shared because the platform share action fails or is unavailable
- **THEN** the app shows visible failure feedback without deleting persisted logs
