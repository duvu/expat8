## ADDED Requirements

### Requirement: Dashboard provides an operations workspace
The dashboard SHALL provide a dedicated operations workspace that helps admins inspect system health, uploaded logs, and recent failure context from one place.

#### Scenario: Admin opens the ops workspace
- **WHEN** an authenticated admin navigates to the ops section
- **THEN** the dashboard displays a dedicated operations landing page with health summary cards and a recent logs panel

#### Scenario: Ops workspace loads without destructive actions
- **WHEN** the ops workspace is opened
- **THEN** the dashboard shows read-only operational information and does not expose restart or redeploy controls

### Requirement: Dashboard shows backend health status
The dashboard SHALL show backend health and readiness information that helps admins quickly determine whether the server is available for learning and log retrieval.

#### Scenario: Backend is healthy
- **WHEN** the backend readiness probe reports healthy
- **THEN** the dashboard displays a healthy status indicator and the last known check time

#### Scenario: Backend is unhealthy
- **WHEN** the backend readiness probe fails or reports unhealthy
- **THEN** the dashboard displays an unhealthy indicator with a visible failure summary

### Requirement: Dashboard lists uploaded log archives
The dashboard SHALL list uploaded log files with upload time, file size, source metadata, and retention state so admins can triage support issues.

#### Scenario: Uploaded log file exists
- **WHEN** at least one uploaded log file is present on the server
- **THEN** the dashboard renders a log archive table with the file name, size, upload time, and source app/device metadata

#### Scenario: No uploaded log files exist
- **WHEN** the server has no uploaded log files
- **THEN** the dashboard shows an empty state that explains how logs are uploaded from the mobile app

### Requirement: Dashboard supports log filtering and drill-down
The dashboard SHALL let admins filter uploaded logs by severity, time range, and text search, and SHALL support drilling into a selected log file or entry.

#### Scenario: Admin filters uploaded logs by severity
- **WHEN** the admin selects a severity filter such as warning or error
- **THEN** the dashboard shows only matching log entries or archives

#### Scenario: Admin opens a log detail view
- **WHEN** the admin selects a log file or row from the archive table
- **THEN** the dashboard opens a detail view showing the log contents and metadata needed for triage
