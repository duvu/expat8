## Purpose
Define the admin user detail view that shows a single learner's proficiency levels, vocabulary cache size, study-event breakdown by rating, and recent activity log.

## Requirements

### Requirement: Dashboard shows per-user proficiency and cache summary
The dashboard SHALL provide a `/users/[id]` page that displays the selected user's display name and identifier, their proficiency level for each language they have studied, and the count of words currently in their local word cache.

#### Scenario: Admin opens a user detail page
- **WHEN** an admin clicks a user row on `/users`
- **THEN** the dashboard renders the user's profile fields, a proficiency table with one row per language, and the count of words in `user_cached_words` for that user

#### Scenario: User has proficiency in multiple languages
- **WHEN** a user has `user_proficiency` rows for `en` and `zh`
- **THEN** the proficiency table shows one row per language with the level and last-updated timestamp

#### Scenario: User has no cached words
- **WHEN** a user has no rows in `user_cached_words`
- **THEN** the words-in-cache count displays as 0

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

### Requirement: Dashboard user detail page is linked from the user list
The dashboard SHALL link each user row on the `/users` page to that user's detail page at `/users/[id]`.

#### Scenario: Admin navigates from user list to user detail
- **WHEN** an admin clicks a user identifier in the `/users` table
- **THEN** the browser navigates to `/users/[id]` for that user
