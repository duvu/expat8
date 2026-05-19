## Why

The expat8-dashboard currently covers only basic admin CRUD workflows (articles, vocabulary review, speaking prompts, exam results list, user list, ops logs). However, it has **zero visibility** into critical operational data: speaking events, SRS word states, word generation runs, article processing job queues, workplace sentences, and exam question-level analytics. There are no time-series charts, no engagement metrics, and no pipeline health indicators. Operators cannot answer basic questions like "how many users studied today?", "what's the exam pass rate this week?", or "is the article processing pipeline healthy?" without querying the database directly.

This redesign will make the dashboard a comprehensive operations center covering **all** backend endpoints and data tables, with appropriate statistics and visualizations.

## What Changes

- **New Analytics Dashboard page** — home page becomes a real-time metrics overview with KPI cards, time-series charts (study events, active users, speaking activity), and pipeline health gauges
- **Study Events Analytics** — daily/weekly trends, rating distribution, active learner counts (DAU/WAU/MAU)
- **Proficiency Analytics** — level distribution histogram, progression tracking
- **Exam Analytics** — pass rate, score distribution, per-topic breakdown, most-missed words
- **Speaking Analytics** — event volume, self-rating distribution, drill completion rates, per-user engagement
- **Article Pipeline Monitor** — processing queue depth, job duration p50/p95, failure rate trend, article status funnel
- **Word Generation Monitor** — run history, success/failure rates, generation throughput
- **SRS Word State Browser** — per-user word states, overdue review counts, ease factor distribution
- **Workplace Sentences Browser** — list/search sentences, per-article breakdown
- **Enhanced User Detail** — add speaking activity tab, SRS state tab, exam history tab
- **Enhanced Article Detail** — inline metadata editing, processing job history, extracted workplace sentences
- **Content Coverage Dashboard** — vocabulary by topic, entry type distribution, quality score histogram
- **Charting library integration** — add a lightweight chart library for time-series and distribution visualizations

## Capabilities

### New Capabilities
- `dashboard-analytics-overview`: Main analytics dashboard with KPI cards and time-series charts for study events, active users, and speaking activity
- `dashboard-study-event-analytics`: Study event trends, rating distribution, DAU/WAU/MAU metrics
- `dashboard-exam-analytics`: Pass rate, score distribution, per-topic breakdown, most-missed words
- `dashboard-speaking-analytics`: Speaking event volume, self-rating distribution, drill completion rates, prompt coverage
- `dashboard-pipeline-monitor`: Article processing queue, job duration, failure rates, word generation run history
- `dashboard-srs-browser`: SRS word state visibility per user, overdue review counts, ease factor distribution
- `dashboard-workplace-sentences`: Workplace sentence browser with article association
- `dashboard-content-coverage`: Vocabulary topic coverage, entry type distribution, quality score metrics

### Modified Capabilities
- `admin-web-dashboard`: Enhanced home page (analytics overview replaces static stats), enhanced user detail (speaking/SRS/exam tabs), enhanced article detail (inline edit, processing jobs, sentences)
- `dashboard-user-learning-stats`: Extended with speaking events, SRS word states, and exam history per user

## Impact

- **Dashboard**: Major UI addition — 6+ new pages/sections, charting library added, new DB queries for aggregations
- **Backend**: No API changes needed — all data accessed via direct DB queries (existing dashboard pattern)
- **Dependencies**: Add a charting library (e.g., `recharts` or `chart.js` via `react-chartjs-2`)
- **Database**: Read-only aggregation queries; may benefit from indexes on `study_events.occurred_at`, `speaking_events.occurred_at`, `article_processing_jobs.status`
- **Performance**: Aggregate queries on large tables need attention — consider materialized views or cron-based snapshots for expensive metrics if tables grow
