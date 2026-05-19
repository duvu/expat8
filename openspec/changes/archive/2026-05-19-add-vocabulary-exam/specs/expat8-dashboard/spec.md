## ADDED Requirements

### Requirement: Dashboard displays an exam results tab
The system SHALL add an "Exam Results" tab to the admin dashboard that lists all exam attempts across all users, with filters for user, topic, language, and date range.

#### Scenario: Admin views exam attempts
- **WHEN** an admin opens the Exam Results tab
- **THEN** the dashboard displays a paginated table of exam attempts showing: user identifier, topic, language, difficulty level, score, pass/fail status, attempt date, and certificate link (if issued)

#### Scenario: Admin filters by user
- **WHEN** the admin enters a user identifier in the filter field
- **THEN** the table updates to show only attempts by that user

#### Scenario: Admin filters by topic or language
- **WHEN** the admin selects a topic or language from the filter dropdowns
- **THEN** the table updates to show only matching attempts

#### Scenario: Admin views certificate
- **WHEN** the admin clicks the certificate link for a passing attempt
- **THEN** the dashboard navigates to or opens the certificate detail view for that certificate ID

### Requirement: Dashboard exam results are read-only
The system SHALL NOT provide any mutation controls (edit, delete, invalidate) for exam attempts or certificates in the dashboard v1. The view is read-only.

#### Scenario: No mutation controls are present
- **WHEN** the admin views the Exam Results tab
- **THEN** there are no buttons or inputs that would modify exam attempts or certificates
