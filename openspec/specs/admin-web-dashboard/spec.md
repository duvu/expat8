## Purpose
Define the browser-based admin interface for creating and managing articles submitted to the backend.

## Requirements

### Requirement: Admin can create articles from the dashboard
The system SHALL provide a browser-based admin form that submits article title, language, raw text, optional source URL, and visibility to the backend for processing.

#### Scenario: Admin submits a new article
- **WHEN** an admin fills the article composer and submits it
- **THEN** the dashboard sends the article data to the backend and displays the created article state

#### Scenario: Missing required article fields are blocked in the UI
- **WHEN** the admin leaves title, language, or raw text empty
- **THEN** the dashboard prevents submission and shows validation feedback

### Requirement: Admin can monitor article processing state
The system SHALL display article processing state, including pending processing, processing, processed, pending review, published, and failed states.

#### Scenario: Processing state changes are visible
- **WHEN** an article transitions between backend states
- **THEN** the dashboard shows the updated state on the article list or detail view

#### Scenario: Processing failures are visible
- **WHEN** an article has a processing error
- **THEN** the dashboard surfaces the error state and the processing error text if present

### Requirement: Admin can review extracted vocabulary items
The system SHALL provide a vocabulary review screen that lists extracted terms and phrases and supports approve, reject, and review-note updates for pending items.

#### Scenario: Admin approves a vocabulary item
- **WHEN** the admin approves a pending vocabulary item from the review table
- **THEN** the dashboard sends the review action to the backend and updates the item status

#### Scenario: Admin rejects a vocabulary item with a note
- **WHEN** the admin rejects a vocabulary item and enters a note
- **THEN** the dashboard sends the rejection and note to the backend and updates the item status

### Requirement: Admin can publish reviewed articles
The system SHALL let admins publish an article after its reviewable vocabulary is ready.

#### Scenario: Admin publishes an article
- **WHEN** the admin clicks publish on a reviewable article
- **THEN** the dashboard requests publication from the backend and shows the published state

### Requirement: Dashboard requests remain authenticated
The system SHALL send admin dashboard requests using the existing backend authentication requirements for app credentials and admin tokens.

#### Scenario: Unauthorized dashboard request is rejected
- **WHEN** the dashboard cannot provide the required authentication headers or token
- **THEN** the backend rejects the request and the dashboard surfaces the failure
