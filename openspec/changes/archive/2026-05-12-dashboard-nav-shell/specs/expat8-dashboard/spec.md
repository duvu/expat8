## MODIFIED Requirements

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
