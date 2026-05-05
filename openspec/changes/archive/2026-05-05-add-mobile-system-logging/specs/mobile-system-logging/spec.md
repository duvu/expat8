## ADDED Requirements

### Requirement: Mobile app captures structured diagnostic logs
The mobile app SHALL capture structured diagnostic logs for key runtime flows using a consistent schema including timestamp, level, category, event name, message, and contextual fields.

#### Scenario: API request lifecycle is logged
- **WHEN** the app sends and receives a backend API call
- **THEN** the app records request and response log events with trace correlation and sanitized context

#### Scenario: Local persistence operations are logged
- **WHEN** the app performs local database read/write or migration operations
- **THEN** the app records corresponding success or failure log events with operation metadata

### Requirement: Logs are persisted locally with retention and rotation
The mobile app MUST persist logs on-device and enforce retention limits by age and count to prevent unbounded storage growth.

#### Scenario: Log retention threshold is exceeded
- **WHEN** persisted logs exceed configured retention age or maximum record count
- **THEN** the app removes oldest log records and preserves newest records within limits

#### Scenario: App restarts after previous logging session
- **WHEN** the app restarts on the same device
- **THEN** previously persisted logs remain queryable until removed by retention policy

### Requirement: Sensitive data is redacted before persistence and export
The mobile app MUST redact sensitive values from logs before writing or exporting entries.

#### Scenario: Log context contains authentication secret
- **WHEN** a log payload includes token, password, app secret, or equivalent sensitive fields
- **THEN** the app replaces sensitive values with redacted placeholders before persistence and export

#### Scenario: Exception text includes sensitive substring
- **WHEN** an exception message includes a known sensitive pattern
- **THEN** the app stores a sanitized message that excludes the original sensitive value

### Requirement: Users can inspect and export logs on-device
The mobile app SHALL provide an in-app log viewer that supports filtering and exporting logs for diagnostics without requiring emulator attachment.

#### Scenario: User filters logs by severity
- **WHEN** the user selects a severity filter in the log viewer
- **THEN** the app displays only log entries matching the selected level range

#### Scenario: User exports logs for debugging
- **WHEN** the user triggers log export
- **THEN** the app generates a shareable log file containing sanitized persisted entries within the selected range
