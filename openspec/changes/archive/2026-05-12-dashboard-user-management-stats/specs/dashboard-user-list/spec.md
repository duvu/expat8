## Purpose
Define the admin user list view that surfaces all registered learners with summary learning metadata so admins can monitor signup growth and user activity.

## ADDED Requirements

### Requirement: Dashboard lists all registered users with learning summary
The dashboard SHALL provide a `/users` page that displays all registered user accounts in a paginated table. Each row SHALL show the user's identifier, display name, signup date, last study event date, and total study event count.

#### Scenario: Admin opens the users page
- **WHEN** an admin navigates to `/users`
- **THEN** the dashboard renders a table of registered users ordered by signup date descending, with up to 50 rows per page

#### Scenario: User has no study events yet
- **WHEN** a registered user has never submitted a study event
- **THEN** the dashboard displays "—" for last activity and 0 for study event count

#### Scenario: User has study events
- **WHEN** a registered user has submitted study events
- **THEN** the dashboard displays the most recent `occurred_at` value as last activity and the total count of study events linked to that user's `user_id`

#### Scenario: Admin paginates through the user list
- **WHEN** more than 50 registered users exist and the admin advances to page 2
- **THEN** the dashboard renders the next 50 users in the same sort order

### Requirement: Dashboard shows aggregate platform stats on home page
The dashboard home page SHALL display a summary stats panel showing total registered users, total study events, distinct active learners in the last 7 days, and total words in the vocabulary table.

#### Scenario: Admin loads the home page
- **WHEN** an admin opens the dashboard home page
- **THEN** a stats panel is visible above the article list with the four aggregate counts rendered as labelled numeric tiles

#### Scenario: No activity in the last 7 days
- **WHEN** no study events have `occurred_at` within the last 7 days
- **THEN** the active-learners tile shows 0
