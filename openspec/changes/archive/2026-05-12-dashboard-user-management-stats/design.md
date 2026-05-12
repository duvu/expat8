## Context

The expat8-dashboard is a Next.js 14 app-router application that connects directly to the production PostgreSQL database via a `pg.Pool` — it bypasses the backend API for all read operations and only calls backend HTTP endpoints for write mutations (article publish, vocabulary review, speaking prompt status). This direct-DB pattern is already established in `src/lib/db.ts` and is the right approach for new admin read-only views: it avoids adding new admin HTTP endpoints to the backend and keeps data access latency low.

The database contains `users`, `user_sessions`, `user_word_states`, `study_events`, `user_proficiency`, and `user_cached_words` tables. All tables are owned by the same PostgreSQL instance the dashboard already connects to, so no new credentials or connection strings are needed.

Current dashboard pages: articles list (`/`), article detail (`/articles/[id]`), vocabulary review (`/review`), speaking prompts (`/speaking-prompts`), exam results (`/exam`). Each page is a Next.js async server component; data loading is a direct `await pool.query(...)` call in the page or a helper function in `db.ts`.

## Goals / Non-Goals

**Goals:**
- Add a `/users` page listing all registered users with last-activity and study-event count
- Add a `/users/[id]` page with per-user proficiency, word-cache size, study-event breakdown by rating, and a recent-activity log (last 20 events)
- Add an aggregate stats panel to the home page (`/`): total users, total study events, active last-7-days, total vocabulary words
- Keep all new data access read-only — no user mutations in this change

**Non-Goals:**
- Adding backend HTTP admin routes for user data (direct DB read is sufficient)
- User deactivation, password reset, or other write operations
- Anonymous device-only learners are surfaced only via study-event counts (no separate device roster)
- Real-time/push updates — static server-side render on each page load is sufficient for admin use

## Decisions

### 1. Direct DB read vs. new backend admin API

**Decision**: Add new query functions to `src/lib/db.ts` that run SQL directly against the database, matching the existing pattern used by `listAdminArticles`, `listPendingVocabulary`, etc.

**Rationale**: The dashboard already owns a direct DB connection string. Adding backend HTTP routes would require: new route handlers in `app.js`, new `hasAdminAccess` checks, new `store` methods, and then HTTP calls from the dashboard — four layers for a read-only admin view. Direct DB queries are simpler, faster to implement, and consistent with all existing dashboard data access.

**Alternative considered**: New `GET /admin/users` and `GET /admin/users/:id` backend API routes. Rejected — disproportionate backend surface area for a read-only admin dashboard feature; also increases the attack surface of the public backend unnecessarily.

### 2. Query design for user learning stats

**Decision**: Use two separate SQL queries per user-detail page:
  - `getUserProfile(userId)`: joins `users` + `user_proficiency` (grouped by language) + `user_sessions` (count) + `user_cached_words` (count)
  - `getUserStudyActivity(userId)`: aggregates `study_events` by rating for summary counts, plus fetches last 20 events ordered by `occurred_at DESC` for the activity log

**Rationale**: Splitting into two queries keeps each one readable and independently optimisable. A single mega-join across all these tables would produce a cartesian explosion of rows before aggregation.

**Alternative considered**: A single CTE query. Viable but harder to debug and test in isolation; rejected in favour of clarity.

### 3. User list pagination

**Decision**: Simple offset pagination with a `page` query parameter and a fixed page size of 50. Last-activity is computed as `MAX(occurred_at)` from `study_events` grouped by `device_id` correlated to the user via `user_sessions` (where user_id matches) or a subquery on `study_events.user_id`.

**Rationale**: The user population is small (early access) and grows slowly. Cursor-based pagination is overkill. Offset pagination is trivial to implement with Next.js `searchParams` and matches the existing article list pattern.

### 4. Stats panel on home page

**Decision**: Add `getDashboardSummaryStats()` to `db.ts` — a single query with four subqueries (or CTEs): total users, total study events, distinct `device_id` + `user_id` active in last 7 days, total word count. Render as a `<section class="stats-panel">` row of four `<dl>` counters above the article table.

**Rationale**: The home page already fetches article data server-side; adding one more DB query is negligible. A visible summary immediately communicates platform health at a glance.

## Risks / Trade-offs

- **Large study_events table scan for last-7-days active count** → Mitigation: `study_events.occurred_at` is an indexed text column (ISO 8601); a `WHERE occurred_at >= ...` substring comparison will be a full scan. For now acceptable at development scale; add a partial index on `study_events(occurred_at)` if this becomes slow.
- **No pagination on user detail activity log** → Only the last 20 events are fetched; risk of missing context for power users with thousands of events. Acceptable for initial implementation — add "load more" if needed.
- **Direct DB connection from dashboard bypasses backend auth layer** → The dashboard is already deployed in the same trusted admin network and uses `EXPAT8_DASHBOARD_DATABASE_URL` which is not exposed publicly. No new risk introduced.

## Migration Plan

1. Add query functions to `src/lib/db.ts` and types to `src/types.ts`
2. Add new pages `src/app/users/page.tsx` and `src/app/users/[id]/page.tsx`
3. Update `src/app/page.tsx` to include the stats panel
4. Update `src/app/layout.tsx` to add the "Users" nav link
5. Rebuild and redeploy the dashboard service (Next.js standalone build)

No database migrations needed. No backend changes needed. Rollback: redeploy previous dashboard image.

## Open Questions

- Should anonymous device learners (users with no `users` record, only `device_id` in study_events) appear in the user list? Current decision: no — the user list shows only registered accounts. A separate "Devices" tab could be added later.
- Should the stats panel count anonymous device activity in the "active last 7 days" metric? Current decision: yes — count distinct `device_id` across all study_events in the window regardless of user_id to give the most accurate picture of actual usage.
