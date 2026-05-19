# dashboard-workplace-sentences Specification

## Purpose
Define the workplace sentences page of the admin dashboard, allowing operators to browse and filter all extracted workplace sentences and view per-article sentence breakdowns on article detail pages.

## Requirements

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
