## MODIFIED Requirements

### Requirement: Dashboard supports article moderation workflows
The system SHALL let admins upload articles, inspect processing state, review vocabulary, review speaking prompts linked to vocabulary, and publish reviewed content.

#### Scenario: Admin uploads an article
- **WHEN** an admin submits title, language, raw text, and optional source URL
- **THEN** the dashboard sends the article to the backend and shows the created state

#### Scenario: Admin reviews vocabulary
- **WHEN** the admin opens the vocabulary review screen
- **THEN** the dashboard lists pending extracted items with term, meaning, usage, and review status

#### Scenario: Admin reviews speaking prompt for vocabulary
- **WHEN** the admin opens a vocabulary item that has a speaking prompt
- **THEN** the dashboard displays editable target text, Vietnamese hint, target phrase, pronunciation tip, common mistake, difficulty, topic, and prompt status fields

## ADDED Requirements

### Requirement: Dashboard supports speaking prompt quality queue
The dashboard SHALL provide an admin workflow for finding speaking prompts that need review or correction before they are served to mobile learners.

#### Scenario: Admin filters prompts awaiting review
- **WHEN** an admin opens the speaking prompt quality queue
- **THEN** the dashboard can list prompts with `pending_review` status and prompts missing required speaking support fields

#### Scenario: Admin approves a speaking prompt
- **WHEN** an admin marks a speaking prompt as approved
- **THEN** the dashboard persists the approved state through an authenticated backend request so the prompt can be served to eligible mobile cards
