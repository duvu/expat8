## MODIFIED Requirements

### Requirement: User detail shows complete learning statistics
The user learning stats page SHALL display study event breakdown by rating, proficiency levels per language, speaking activity metrics, SRS word state summary, and exam attempt history.

#### Scenario: Study event breakdown shows all ratings
- **WHEN** an operator views a user's learning stats
- **THEN** the page shows total counts and trend for each rating type (easy, too_easy, hard, too_hard)

#### Scenario: Speaking metrics are included
- **WHEN** an operator views a user's learning stats
- **THEN** metrics include total speaking events, drill completions, average self-rating, and last speaking date

#### Scenario: SRS state summary is included
- **WHEN** an operator views a user's learning stats
- **THEN** a summary shows word count by SRS status (new, learning, review, completed) and overdue count

#### Scenario: Exam history is included
- **WHEN** an operator views a user's learning stats
- **THEN** a table shows all exam attempts with topic, score, pass/fail, and date
