## Purpose
Define the authenticated article ingestion APIs that accept textual learning content and persist ownership, language, and lifecycle metadata.

## ADDED Requirements

### Requirement: Authenticated users can upload and manage articles
The system SHALL provide authenticated article ingestion APIs that accept textual learning content and persist article ownership, language, and lifecycle metadata.

#### Scenario: User uploads a valid article
- **WHEN** an authenticated user submits `POST /v1/articles` with title, language, and raw_text within size limits
- **THEN** the system creates an article owned by that user with status `pending_processing` and returns article metadata including processing status

#### Scenario: Unauthorized upload is rejected
- **WHEN** a client calls `POST /v1/articles` without a valid bearer session
- **THEN** the system rejects the request with authentication error and does not create an article

### Requirement: Article reads enforce ownership and visibility
The system SHALL restrict article detail and article vocabulary reads by ownership/visibility policy.

#### Scenario: Owner reads own private article
- **WHEN** the owner requests `GET /v1/articles/:id`
- **THEN** the system returns the article and latest processing status

#### Scenario: Non-owner reads private article
- **WHEN** another user requests `GET /v1/articles/:id` for a private article
- **THEN** the system returns access denied and does not reveal article content
