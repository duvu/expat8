## Purpose
Define how the expat8-dashboard service provides the browser-based admin workflow for article upload, moderation, vocabulary review, and publishing while remaining authenticated against backend admin APIs.

## Requirements
### Requirement: Dashboard is deployable as a named service
The system SHALL provide a dashboard service named `expat8-dashboard` that can be built and run as a standalone browser-facing application.

#### Scenario: Dashboard service is built
- **WHEN** an operator builds the dashboard service
- **THEN** the build produces a runnable `expat8-dashboard` artifact

#### Scenario: Dashboard service starts
- **WHEN** the dashboard service is started with required runtime configuration
- **THEN** the service starts and serves the admin dashboard UI

### Requirement: Dashboard supports article moderation workflows
The system SHALL let admins upload articles, inspect processing state, review vocabulary, and publish reviewed content.

#### Scenario: Admin uploads an article
- **WHEN** an admin submits title, language, raw text, and optional source URL
- **THEN** the dashboard sends the article to the backend and shows the created state

#### Scenario: Admin reviews vocabulary
- **WHEN** the admin opens the vocabulary review screen
- **THEN** the dashboard lists pending extracted items with term, meaning, usage, and review status

### Requirement: Dashboard requests remain authenticated
The system SHALL send backend requests using the existing app credential and admin token model.

#### Scenario: Dashboard request is authenticated
- **WHEN** the dashboard submits a mutation to the backend
- **THEN** the request includes the required app credential headers and admin token where applicable
