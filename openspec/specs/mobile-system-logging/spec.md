## Purpose
Define how the mobile app captures, retains, redacts, inspects, and exports diagnostic logs for support and debugging on real devices.
## Requirements
### Requirement: Mobile app captures structured diagnostic logs
The mobile app SHALL capture structured diagnostic logs for key runtime flows using a consistent schema including timestamp, level, category, event name, message, and contextual fields.

#### Scenario: API request lifecycle is logged
- **WHEN** the app sends and receives a backend API call
- **THEN** the app records request and response log events with trace correlation and sanitized context

#### Scenario: Local persistence operations are logged
- **WHEN** the app performs local database read/write or migration operations
- **THEN** the app records corresponding success or failure log events with operation metadata

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

### Requirement: Sensitive data is redacted before persistence and export
The mobile app MUST redact sensitive values from logs before writing or exporting entries.

#### Scenario: Log context contains authentication secret
- **WHEN** a log payload includes token, password, app secret, or equivalent sensitive fields
- **THEN** the app replaces sensitive values with redacted placeholders before persistence and export

#### Scenario: Exception text includes sensitive substring
- **WHEN** an exception message includes a known sensitive pattern
- **THEN** the app stores a sanitized message that excludes the original sensitive value

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

### Requirement: Mobile logs card-selection decisions and empty-card causes
The mobile app SHALL record structured diagnostic logs for learning-card selection decisions, fallback paths, and final empty-card causes.

#### Scenario: Card selection starts
- **WHEN** the session controller begins selecting the next card
- **THEN** the app records the requested selection mode, active learning language, preferred card kind, and rolling mix state

#### Scenario: Selector falls back from new to review
- **WHEN** the preferred card kind is new-word and no new word is available
- **THEN** the app records a fallback event before attempting learned or reviewable card selection

#### Scenario: Selector falls back from review to new
- **WHEN** the preferred card kind is review and no learned or reviewable card is available
- **THEN** the app records a fallback event before attempting new-word card selection

#### Scenario: Selector cannot find any card
- **WHEN** no new, learned, due-review, difficult-relearn, or recent-review card is available
- **THEN** the app records an empty-card event that includes the attempted sources and active learning language

