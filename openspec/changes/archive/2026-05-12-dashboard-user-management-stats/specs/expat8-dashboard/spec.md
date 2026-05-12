## MODIFIED Requirements

### Requirement: Dashboard supports article moderation workflows
The system SHALL let admins upload articles, inspect processing state, review vocabulary, review speaking prompts linked to vocabulary, and publish reviewed content. The dashboard navigation SHALL also provide access to user management and learning statistics views.

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
- **WHEN** the admin clicks the "Users" navigation link
- **THEN** the browser navigates to `/users` and renders the registered user list
