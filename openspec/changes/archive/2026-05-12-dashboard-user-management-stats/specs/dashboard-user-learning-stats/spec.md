## Purpose
Define the admin user detail view that shows a single learner's proficiency levels, vocabulary cache size, study-event breakdown by rating, and recent activity log.

## ADDED Requirements

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

### Requirement: Dashboard shows per-user study-event breakdown and activity log
The dashboard SHALL display the selected user's study events grouped by rating as a summary table, and list the 20 most recent study events with word ID, rating, and timestamp as an activity log.

#### Scenario: Admin views study event breakdown
- **WHEN** a user has submitted study events with ratings 1 through 5
- **THEN** the dashboard renders a breakdown table with each distinct rating and its event count

#### Scenario: Admin views recent activity log
- **WHEN** a user has submitted at least one study event
- **THEN** the dashboard lists the 20 most recent events ordered by `occurred_at` descending, showing word ID (or local_word_id if word_id is null), rating, and occurred_at

#### Scenario: User has no study events
- **WHEN** a user has submitted no study events
- **THEN** the dashboard shows an empty-state message for both the breakdown table and the activity log

### Requirement: Dashboard user detail page is linked from the user list
The dashboard SHALL link each user row on the `/users` page to that user's detail page at `/users/[id]`.

#### Scenario: Admin navigates from user list to user detail
- **WHEN** an admin clicks a user identifier in the `/users` table
- **THEN** the browser navigates to `/users/[id]` for that user
