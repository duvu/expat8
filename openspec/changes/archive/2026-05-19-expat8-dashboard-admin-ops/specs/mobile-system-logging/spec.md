## MODIFIED Requirements

### Requirement: Users can inspect and export logs on-device
The mobile app SHALL provide an in-app log viewer that supports filtering and exporting sanitized logs as a shareable text file through the device share sheet without requiring emulator attachment, and SHALL provide a send-to-server action for the same sanitized log bundle.

#### Scenario: User filters logs by severity
- **WHEN** the user selects a severity filter in the log viewer
- **THEN** the app displays only log entries matching the selected level range

#### Scenario: User exports logs for debugging
- **WHEN** the user triggers log export and matching logs exist
- **THEN** the app generates a UTF-8 text file containing sanitized persisted entries within the selected range and opens the platform share sheet with that file attached

#### Scenario: User sends logs to the server
- **WHEN** the user taps the send-logs action and matching logs exist
- **THEN** the app uploads the sanitized log file to the authenticated backend archive endpoint and shows success feedback

#### Scenario: User exports logs when none match
- **WHEN** the user triggers log export and no persisted logs match the selected filters
- **THEN** the app shows visible feedback that there are no logs to export and does not open an empty share sheet

#### Scenario: Share action fails or is unavailable
- **WHEN** the generated log file cannot be shared because the platform share action fails or is unavailable
- **THEN** the app shows visible failure feedback without deleting persisted logs
