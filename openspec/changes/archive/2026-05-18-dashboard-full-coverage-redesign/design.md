## Context

The expat8-dashboard is a Next.js 15 app using React 19 Server Components with `force-dynamic` rendering. It has only 4 runtime dependencies (`next`, `react`, `react-dom`, `pg`). Pages are server-rendered with no client-side state library. Data access uses a dual pattern: direct PostgreSQL queries for reads, HMAC-signed backend API calls for mutations. The database schema has 23+ tables covering words, study events, users, sessions, proficiency, articles, processing jobs, vocabulary review, exams, speaking events/prompts, and generation runs.

Current dashboard architecture: all pages under `src/app/` using App Router; shared components in `src/components/` (PageShell, Sidebar, SidebarNav, Toolbar); data access in `src/lib/` (backend.ts for API calls, db.ts for PostgreSQL pool). Custom CSS design system in `globals.css` — no Tailwind, no component library.

## Goals / Non-Goals

**Goals:**
- Cover every backend data table with appropriate admin visibility
- Provide time-series charts and aggregate statistics for key metrics
- Make the home page a true operations overview (not just an article list)
- Enable data-driven decisions about content pipeline, learner engagement, and speaking adoption
- Keep the server-rendered architecture (no SPA, no client-side data fetching)
- Maintain minimal dependency footprint

**Non-Goals:**
- Real-time websocket updates (page refresh is acceptable)
- User-facing analytics (this is admin-only)
- Complex OLAP queries or data warehouse integration
- Changing the backend API or adding new endpoints
- Adding authentication to the dashboard (remains network-level access control)
- Replacing the custom CSS with Tailwind or a component library

## Decisions

### D1: Charting library — Recharts

**Decision**: Use `recharts` (React-based, composable, SSR-compatible via dynamic import with `ssr: false`).

**Rationale**: Recharts is React-native, uses SVG (no canvas), composable API, actively maintained, ~45KB gzipped. Works with Next.js dynamic imports for client-side rendering of charts while keeping the page shell server-rendered.

**Alternatives considered**:
- `chart.js` / `react-chartjs-2`: Canvas-based, heavier, less React-native
- `nivo`: Beautiful but heavy (~200KB+)
- `visx`: Low-level, requires more code for common patterns
- D3 direct: Too low-level for admin dashboards

### D2: Page architecture — Mixed server/client components

**Decision**: Pages remain async Server Components for layout and data fetching. Chart sections are wrapped in `'use client'` components that receive pre-fetched data as props. No client-side data fetching (no SWR/React Query).

**Rationale**: Keeps the existing architecture intact. Server Components fetch data, client components render charts. Minimal client JS bundle — only chart rendering code ships to browser.

```
┌─────────────────────────────────────────┐
│   Server Component (page.tsx)           │
│   ┌─────────────────────────────────┐   │
│   │  await db.query(...)            │   │
│   │  const data = aggregate(rows)   │   │
│   └─────────────────────────────────┘   │
│                 │ props                  │
│                 ▼                        │
│   ┌─────────────────────────────────┐   │
│   │  'use client' ChartPanel        │   │
│   │  <LineChart data={data} />      │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### D3: Navigation structure — Grouped sidebar

**Decision**: Restructure sidebar into logical groups:

```
Dashboard (home)
─────────────────
Content
  ├── Articles
  ├── Vocabulary Review
  ├── Speaking Prompts
  └── Workplace Sentences
Analytics
  ├── Study Events
  ├── Exam Results
  ├── Speaking
  └── Proficiency
System
  ├── Users
  ├── Pipeline
  ├── Generation
  └── Ops / Logs
```

### D4: Data aggregation — SQL-level with optional DB indexes

**Decision**: All aggregations done in PostgreSQL queries at request time. Add indexes on timestamp columns used for time-range filtering. For expensive aggregations (e.g., DAU over 90 days), use PostgreSQL `date_trunc` + `GROUP BY`.

**Rationale**: Simpler than cron/materialized views. Dashboard is admin-only (low traffic), and Postgres can handle these aggregates efficiently with proper indexes. If performance becomes an issue later, add materialized views as optimization.

### D5: Time range selector pattern

**Decision**: Each analytics page has a shared `TimeRangeSelector` component (7d / 30d / 90d / all). The selected range is passed as a URL search param (`?range=30d`), allowing server-side filtering without client state.

### D6: Chart components — Reusable wrappers

**Decision**: Create a small set of reusable chart wrappers in `src/components/charts/`:
- `TimeSeriesChart` — line/area chart with date x-axis
- `BarChart` — category comparison
- `PieChart` — distribution/proportion
- `KpiCard` — single metric with optional sparkline

These wrap Recharts primitives and apply consistent styling.

## Risks / Trade-offs

- **[Risk] Large aggregate queries on study_events/speaking_events** → Mitigate with indexes on `(occurred_at)`, `(device_id, occurred_at)` and reasonable default time ranges (30 days). Monitor query performance.
- **[Risk] Recharts SSR complications** → Mitigate with `dynamic(() => import(...), { ssr: false })` for all chart components. This is a well-established Next.js pattern.
- **[Risk] Dashboard page count grows significantly (6+ new pages)** → Mitigate with grouped sidebar navigation and consistent page shell pattern (PageShell + Toolbar).
- **[Risk] Cold-start page load time for complex queries** → Mitigate with `loading.tsx` skeleton states (already used for ops pages). Consider query parallelization within pages.
- **[Trade-off] No real-time updates** → Acceptable: admin dashboard refreshes on navigation. Manual refresh button is sufficient.
- **[Trade-off] Aggregate queries computed per-request** → Acceptable at current scale (single-digit admin users). Add materialized views later if needed.
