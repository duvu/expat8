## Why

The expat8-dashboard gives admins full visibility into content (articles, vocabulary, speaking prompts, exam results) but is blind to the learner population: there is no way to see how many users have registered, which users are actively studying, or how individual learners are progressing. As the app moves from internal testing to broader rollout, admins need a user roster and per-user learning stats to monitor adoption, triage support requests, and validate that the SRS pipeline is working as intended.

## What Changes

- **New page `/users`**: Paginated table of registered users showing identifier, display name, signup date, last study activity, and total study-event count.
- **New page `/users/[id]`**: User detail page showing profile fields, per-language proficiency level, words-in-cache count, study-event breakdown by rating, and a recent-activity timeline (last 20 study events).
- **Dashboard home page gains a stats panel**: Aggregate counts — total registered users, total study events, active users in the last 7 days, words in the vocabulary table — rendered as a summary row above the article list.
- **Nav gains a "Users" link** alongside the existing article/review/speaking-prompts/exam links.
- **New direct-DB queries in `db.ts`**: `listUsers`, `getUserDetail`, `getUserStudyStats`, `getDashboardSummaryStats` — all read-only, using the existing direct PostgreSQL pool already used by the dashboard.
- No backend API routes are added; the dashboard reads directly from the DB as it already does for all other read operations.
- No destructive actions on users in this change (read-only user management).

## Capabilities

### New Capabilities

- `dashboard-user-list`: Admin can list all registered users with summary learning metadata (signup date, last activity, study event count, proficiency level per language).
- `dashboard-user-learning-stats`: Admin can view a single user's full learning detail — proficiency per language, words currently in cache, study-event history broken down by rating, and a recent-activity log.

### Modified Capabilities

- `expat8-dashboard`: Home page gains an aggregate stats panel; nav gains a "Users" entry; the overall dashboard now covers user visibility in addition to content moderation.

## Impact

- **Dashboard**: New pages `src/app/users/page.tsx`, `src/app/users/[id]/page.tsx`; updated `src/app/page.tsx` (stats panel) and `src/app/layout.tsx` (nav link); new query functions in `src/lib/db.ts`; new types in `src/types.ts`.
- **Database**: Read-only queries against `users`, `user_sessions`, `study_events`, `user_word_states`, `user_proficiency`, `user_cached_words`. No schema changes required.
- **Backend**: No changes.
- **Mobile**: No changes.
