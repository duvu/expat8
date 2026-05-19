## ADDED Requirements

### Requirement: SRS word states are browsable per user
The dashboard SHALL provide an SRS browser page where operators can view word states for a specific user/device, showing status, ease_factor, review_count, and next_review_at.

#### Scenario: Word states are listed for a user
- **WHEN** an operator selects a user and navigates to their SRS state view
- **THEN** a table shows all word states with columns: word term, status, ease_factor, review_count, next_review_at

### Requirement: Overdue review count is computed
The dashboard SHALL show the total count of words overdue for review (next_review_at < now) across all users.

#### Scenario: Overdue count is displayed as a KPI
- **WHEN** an operator views the SRS browser page
- **THEN** a KPI card shows the total overdue word count across all users

### Requirement: SRS status distribution is visualized
The dashboard SHALL show the distribution of word states across statuses (new, learning, review, completed).

#### Scenario: Status distribution chart is displayed
- **WHEN** an operator views the SRS browser page
- **THEN** a pie chart shows the proportion of words in each SRS status
