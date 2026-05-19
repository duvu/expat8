## ADDED Requirements

### Requirement: Workplace sentences are browsable
The dashboard SHALL provide a workplace sentences page listing all sentences with topic, language, source article, and creation date.

#### Scenario: Sentences table is displayed
- **WHEN** an operator navigates to the workplace sentences page
- **THEN** a paginated table shows sentences with columns: sentence text (truncated), topic, language, source article, created_at

#### Scenario: Sentences can be filtered by topic and language
- **WHEN** an operator applies topic or language filters
- **THEN** the table shows only matching workplace sentences

### Requirement: Per-article sentence breakdown is visible
The dashboard SHALL show which workplace sentences were extracted from each article on the article detail page.

#### Scenario: Article detail shows extracted sentences
- **WHEN** an operator views an article detail page
- **THEN** a section lists all workplace sentences associated with that article
