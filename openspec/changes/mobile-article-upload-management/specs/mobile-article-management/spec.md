## ADDED Requirements

### Requirement: Signed-in users can create articles from text
The mobile app SHALL provide a text-first article creation flow that submits `title`, `language`, `raw_text`, and optional `source_url` to the authenticated article API.

#### Scenario: User creates a valid article
- **WHEN** a signed-in user submits a title, language, and raw text that satisfy backend validation
- **THEN** the app creates the article through `POST /v1/articles` and shows the returned article state

#### Scenario: Invalid article input is rejected locally or by the API
- **WHEN** the user submits a blank title, blank language, or blank raw text
- **THEN** the app prevents submission or shows the backend validation error without creating an article

### Requirement: Users can browse their own articles
The mobile app SHALL list the current user's articles using the authenticated article list endpoint and SHALL show article status and timestamps.

#### Scenario: User opens article list
- **WHEN** a signed-in user opens the article management area
- **THEN** the app fetches `GET /v1/articles` and displays the user's articles ordered by recency

#### Scenario: Article list reflects processing state
- **WHEN** an article is pending, processing, processed, published, or failed
- **THEN** the list shows that status and any available processing error text

### Requirement: Users can inspect article details and extracted vocabulary
The mobile app SHALL provide an article detail view that shows article metadata, processing status, processing errors, and extracted vocabulary when available.

#### Scenario: User opens article detail
- **WHEN** a signed-in user selects one of their articles
- **THEN** the app fetches `GET /v1/articles/:id` and `GET /v1/articles/:id/vocabulary` and renders the returned data

#### Scenario: Article has no vocabulary yet
- **WHEN** the article is still processing or has not produced vocabulary yet
- **THEN** the detail view shows an empty state rather than failing

### Requirement: Owners can delete their articles
The mobile app SHALL allow the owning user to soft-delete an article through the authenticated delete endpoint.

#### Scenario: User deletes an owned article
- **WHEN** the user confirms delete on one of their articles
- **THEN** the app calls `DELETE /v1/articles/:id`, removes the article from the list, and shows success feedback

#### Scenario: Delete action is unavailable for non-owned content
- **WHEN** an article is not owned by the current signed-in user
- **THEN** the app does not present a delete action for that article
