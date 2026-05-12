## 1. Types and DB Query Functions

- [x] 1.1 In `expat8-dashboard/src/types.ts`, add `UserRow` type: `{ id, identifier, display_name, created_at, last_activity: string | null, study_event_count: number }`
- [x] 1.2 In `expat8-dashboard/src/types.ts`, add `UserDetail` type: `{ id, identifier, display_name, created_at, session_count: number, cached_word_count: number }`
- [x] 1.3 In `expat8-dashboard/src/types.ts`, add `UserProficiency` type: `{ language, level, updated_at }`
- [x] 1.4 In `expat8-dashboard/src/types.ts`, add `StudyEventSummary` type: `{ rating, count: number }` and `RecentStudyEvent` type: `{ id, word_id: string | null, local_word_id: string | null, rating, occurred_at }`
- [x] 1.5 In `expat8-dashboard/src/types.ts`, add `DashboardSummaryStats` type: `{ total_users, total_study_events, active_last_7_days, total_words: number }`
- [x] 1.6 In `expat8-dashboard/src/lib/db.ts`, add `listUsers({ page?: number })` function: queries `users` LEFT JOIN `study_events` on `user_id` for `MAX(occurred_at)` and `COUNT(*)`, ORDER BY `users.created_at DESC`, LIMIT 50 OFFSET `(page-1)*50`
- [x] 1.7 In `expat8-dashboard/src/lib/db.ts`, add `getUserDetail(userId: string)` function: queries `users` for profile fields + `user_sessions` COUNT + `user_cached_words` COUNT
- [x] 1.8 In `expat8-dashboard/src/lib/db.ts`, add `getUserProficiency(userId: string)` function: queries `user_proficiency` WHERE `user_id = $1` ordered by language
- [x] 1.9 In `expat8-dashboard/src/lib/db.ts`, add `getUserStudyStats(userId: string)` function: returns rating breakdown (`SELECT rating, COUNT(*) FROM study_events WHERE user_id = $1 GROUP BY rating`) and last 20 events (`SELECT id, word_id, local_word_id, rating, occurred_at FROM study_events WHERE user_id = $1 ORDER BY occurred_at DESC LIMIT 20`)
- [x] 1.10 In `expat8-dashboard/src/lib/db.ts`, add `getDashboardSummaryStats()` function: single query with CTEs returning `total_users`, `total_study_events`, `active_last_7_days` (distinct device_id where occurred_at >= 7 days ago), `total_words`

## 2. Users List Page

- [x] 2.1 Create `expat8-dashboard/src/app/users/page.tsx` as an async server component accepting `searchParams: Promise<{ page?: string }>`
- [x] 2.2 In the page, call `listUsers({ page })` and render a `<table>` with columns: Identifier (linked to `/users/[id]`), Display Name, Signed Up, Last Activity, Study Events
- [x] 2.3 Add pagination controls: "Previous" link (disabled on page 1) and "Next" link, passing `?page=N` query param
- [x] 2.4 Add empty-state row when no users exist

## 3. User Detail Page

- [x] 3.1 Create `expat8-dashboard/src/app/users/[id]/page.tsx` as an async server component accepting `params: Promise<{ id: string }>`
- [x] 3.2 Fetch `getUserDetail(id)`, `getUserProficiency(id)`, and `getUserStudyStats(id)` in parallel using `Promise.all`
- [x] 3.3 Render a profile header section: identifier, display name, signup date, session count, cached word count
- [x] 3.4 Render a proficiency table with columns: Language, Level, Last Updated (empty-state if no rows)
- [x] 3.5 Render a study event breakdown table with columns: Rating, Count (empty-state if no rows)
- [x] 3.6 Render a recent activity log table with columns: Word ID / Local ID, Rating, Occurred At (last 20 events, empty-state if none)
- [x] 3.7 Add a "← Back to users" link at the top of the page

## 4. Home Page Stats Panel

- [x] 4.1 In `expat8-dashboard/src/app/page.tsx`, call `getDashboardSummaryStats()` alongside `listAdminArticles`
- [x] 4.2 Render a `<section class="stats-panel">` above the article table with four `<dl>` tiles: "Users", "Study Events", "Active (7d)", "Words"
- [x] 4.3 Add `.stats-panel` CSS to the global stylesheet (or inline in the page) with a horizontal tile layout matching the existing table-panel style

## 5. Navigation Update

- [x] 5.1 In `expat8-dashboard/src/app/layout.tsx` (or wherever the nav is rendered), add `<Link href="/users">Users</Link>` alongside the existing nav links

## 6. Verification

- [x] 6.1 Run `cd expat8-dashboard && npm run build` — build completes with no TypeScript errors
- [ ] 6.2 Start the dashboard locally and verify `/users` renders the user table (or shows empty state if DB is empty)
- [ ] 6.3 Verify `/users/[id]` renders proficiency, stats breakdown, and recent activity for a known test user
- [ ] 6.4 Verify the home page stats panel shows all four counts without error
