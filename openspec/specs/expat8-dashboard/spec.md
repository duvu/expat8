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
The system SHALL let admins upload articles, inspect processing state, review vocabulary, review speaking prompts linked to vocabulary, and publish reviewed content. Navigation to all sections SHALL be provided by the shared left sidebar — individual pages SHALL NOT render their own navigation headers.

#### Scenario: Admin uploads an article
- **WHEN** an admin submits title, language, raw text, and optional source URL
- **THEN** the dashboard sends the article to the backend and shows the created state

#### Scenario: Admin reviews vocabulary
- **WHEN** the admin opens the vocabulary review screen
- **THEN** the dashboard lists pending extracted items with term, meaning, usage, and review status

#### Scenario: Admin reviews speaking prompt for vocabulary
- **WHEN** the admin opens a vocabulary item that has a speaking prompt
- **THEN** the dashboard displays editable target text, Vietnamese hint, target phrase, pronunciation tip, common mistake, difficulty, topic, and prompt status fields

#### Scenario: Admin navigates to users section
- **WHEN** the admin clicks the "Users" navigation link in the left sidebar
- **THEN** the browser navigates to `/users` and renders the registered user list

#### Scenario: No per-page navigation header is rendered
- **WHEN** an admin loads any dashboard page
- **THEN** the page body does not contain a duplicate `<header>` / `<nav>` block — all navigation is in the shared sidebar

### Requirement: Dashboard requests remain authenticated
The system SHALL send backend requests using the existing app credential and admin token model.

#### Scenario: Dashboard request is authenticated
- **WHEN** the dashboard submits a mutation to the backend
- **THEN** the request includes the required app credential headers and admin token where applicable

### Requirement: Dashboard supports speaking prompt quality queue
The dashboard SHALL provide an admin workflow for finding speaking prompts that need review or correction before they are served to mobile learners.

#### Scenario: Admin filters prompts awaiting review
- **WHEN** an admin opens the speaking prompt quality queue
- **THEN** the dashboard can list prompts with `pending_review` status and prompts missing required speaking support fields

#### Scenario: Admin approves a speaking prompt
- **WHEN** an admin marks a speaking prompt as approved
- **THEN** the dashboard persists the approved state through an authenticated backend request so the prompt can be served to eligible mobile cards

### Requirement: Dashboard image is publishable to the registry
The dashboard SHALL be buildable as a Docker image and publishable to `<YOUR_REGISTRY>/expat8-dashboard` using the same `YYYYMMDD.HHMM` tag convention as the backend.

#### Scenario: Dashboard image builds successfully
- **WHEN** an operator runs `docker build` from the `expat8-dashboard/` directory
- **THEN** the multi-stage Next.js build completes and produces a runnable image

#### Scenario: Dashboard image is pushed to registry
- **WHEN** operator pushes the tagged dashboard image
- **THEN** the registry accepts it and it can be pulled by the Z440 host

#### Scenario: Dashboard container serves the admin UI
- **WHEN** the dashboard container runs with `EXPAT8_DASHBOARD_DATABASE_URL` and `BACKEND_BASE_URL` set
- **THEN** the Next.js app serves the admin UI on port 3000 and pages load without error

