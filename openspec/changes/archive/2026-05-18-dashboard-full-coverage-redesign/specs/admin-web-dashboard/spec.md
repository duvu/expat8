## MODIFIED Requirements

### Requirement: Dashboard home page provides operational overview
The admin web dashboard home page SHALL serve as an operations center with real-time KPI metrics, activity charts, and pipeline health summary instead of a static article list.

#### Scenario: Home page shows analytics overview
- **WHEN** an operator navigates to the dashboard root
- **THEN** the page displays KPI cards, an activity trend chart, and a pipeline health summary

#### Scenario: Articles list is accessible from navigation
- **WHEN** an operator wants to manage articles
- **THEN** the articles list is accessible via the Content > Articles navigation item

### Requirement: User detail page shows comprehensive learning data
The user detail page SHALL include tabbed sections for: profile info, study events, speaking activity, SRS word states, and exam history.

#### Scenario: Speaking activity tab is available
- **WHEN** an operator views a user detail page and clicks the Speaking tab
- **THEN** the tab shows that user's speaking events, self-rating distribution, and drill completion count

#### Scenario: Exam history tab is available
- **WHEN** an operator views a user detail page and clicks the Exams tab
- **THEN** the tab shows all exam attempts for that user with scores and pass/fail status

### Requirement: Article detail page shows processing history and sentences
The article detail page SHALL display processing job history (attempts, duration, errors) and extracted workplace sentences.

#### Scenario: Processing job history is visible
- **WHEN** an operator views an article detail page
- **THEN** a section shows all processing job records for that article with status, duration, and error messages

#### Scenario: Inline metadata editing is supported
- **WHEN** an operator wants to edit article title, language, or visibility
- **THEN** inline edit controls allow modifying these fields via PATCH API

### Requirement: Sidebar navigation is grouped by domain
The sidebar SHALL organize pages into logical groups: Content, Analytics, System.

#### Scenario: Navigation groups are visible
- **WHEN** an operator views the sidebar
- **THEN** pages are organized under Content (Articles, Vocabulary Review, Speaking Prompts, Workplace Sentences), Analytics (Study Events, Exam, Speaking, Proficiency), and System (Users, Pipeline, Ops/Logs)
