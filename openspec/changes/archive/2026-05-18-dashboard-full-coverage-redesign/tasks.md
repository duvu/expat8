## 1. Setup & Infrastructure

- [x] 1.1 Install `recharts` as a dependency in `expat8-dashboard/`
- [x] 1.2 Create reusable chart wrapper components in `src/components/charts/`: `TimeSeriesChart.tsx`, `BarChart.tsx`, `PieChart.tsx`, `KpiCard.tsx` (all `'use client'`)
- [x] 1.3 Create `TimeRangeSelector.tsx` component (7d/30d/90d selector using URL search params)
- [x] 1.4 Restructure `Sidebar.tsx` / `SidebarNav.tsx` with grouped navigation (Content, Analytics, System)
- [x] 1.5 Add database indexes: migration `20260519_dashboard_analytics_indexes.sql` created
- [x] 1.6 Run `npm run build` to verify no breakage after setup changes

## 2. Analytics Overview (Home Page Redesign)

- [x] 2.1 Create data queries in `src/lib/analytics.ts`: KPI aggregation (total users, active 7d, study events today, exam pass rate, speaking drills this week)
- [x] 2.2 Create query for daily activity time-series (study events + unique learners per day)
- [x] 2.3 Create query for pipeline health summary (pending jobs, failed 24h, p50 duration)
- [x] 2.4 Rewrite `src/app/page.tsx` as analytics overview: KPI cards row + activity chart + pipeline summary
- [x] 2.5 Move articles list to `src/app/articles/page.tsx` (if not already there)

## 3. Study Events Analytics Page

- [x] 3.1 Create `src/app/analytics/study-events/page.tsx`
- [x] 3.2 Implement query: daily study events grouped by rating (stacked area chart data)
- [x] 3.3 Implement DAU/WAU/MAU computation queries
- [x] 3.4 Add stacked area chart for rating distribution over time
- [x] 3.5 Add KPI cards for DAU, WAU, MAU
- [ ] 3.6 Add filterable study events table with pagination

## 4. Exam Analytics Page

- [x] 4.1 Create `src/app/analytics/exam/page.tsx`
- [x] 4.2 Implement query: overall pass rate, total attempts, average score
- [x] 4.3 Implement query: score distribution histogram (buckets: 0-10, 10-20, ..., 90-100)
- [x] 4.4 Implement query: pass rate by topic and language
- [ ] 4.5 Implement query: most-missed words (join exam_questions with answers)
- [x] 4.6 Add KPI cards (pass rate, total attempts, avg score)
- [x] 4.7 Add score distribution histogram chart
- [x] 4.8 Add per-topic breakdown bar chart
- [ ] 4.9 Add most-missed words table (top 20)

## 5. Speaking Analytics Page

- [x] 5.1 Create `src/app/analytics/speaking/page.tsx`
- [x] 5.2 Implement query: daily speaking events by event type
- [x] 5.3 Implement query: self-rating distribution (clear/hesitated/could_not_say counts)
- [x] 5.4 Implement query: drill completion rate and average recording duration
- [x] 5.5 Implement query: prompt coverage (approved prompts / total word senses)
- [x] 5.6 Add time-series chart for speaking event volume
- [x] 5.7 Add pie/donut chart for self-rating distribution
- [x] 5.8 Add KPI cards (completion rate, avg duration, prompt coverage %)

## 6. Pipeline Monitor Page

- [x] 6.1 Create `src/app/system/pipeline/page.tsx`
- [x] 6.2 Implement query: article count by status (funnel data)
- [x] 6.3 Implement query: processing job queue depth and failure count
- [x] 6.4 Implement query: p50/p95 job duration
- [x] 6.5 Implement query: generation_runs history
- [x] 6.6 Add article status funnel bar chart
- [x] 6.7 Add KPI cards (queue depth, p50/p95 duration, failure rate)
- [x] 6.8 Add generation runs table with status/counts/errors
- [ ] 6.9 Add generation success/failure bar chart over time

## 7. SRS Browser Page

- [x] 7.1 Create `src/app/system/srs/page.tsx`
- [x] 7.2 Implement query: global SRS status distribution (new/learning/review/completed)
- [x] 7.3 Implement query: total overdue word count
- [x] 7.4 Implement query: per-user word states with filtering (accepts user_id param)
- [x] 7.5 Add SRS status distribution pie chart
- [x] 7.6 Add overdue count KPI card
- [x] 7.7 Add per-user word states table (linked from user detail page)

## 8. Workplace Sentences Page

- [x] 8.1 Create `src/app/content/workplace-sentences/page.tsx`
- [x] 8.2 Implement query: list workplace sentences with article join, pagination, topic/language filters
- [x] 8.3 Add filterable paginated sentences table
- [x] 8.4 Update article detail page to show associated workplace sentences section

## 9. Content Coverage Page

- [x] 9.1 Create `src/app/analytics/content/page.tsx`
- [x] 9.2 Implement query: word count by topic
- [x] 9.3 Implement query: entry type distribution (word/phrase/idiom)
- [x] 9.4 Implement query: quality_score histogram from word_senses
- [x] 9.5 Implement query: daily vocabulary review throughput (approved/rejected)
- [x] 9.6 Add topic coverage bar chart
- [x] 9.7 Add entry type pie chart
- [x] 9.8 Add quality score histogram
- [x] 9.9 Add review throughput stacked bar chart

## 10. Enhanced User Detail

- [x] 10.1 Add tabbed layout to `src/app/users/[id]/page.tsx` (Profile, Study Events, Speaking, SRS, Exams)
- [x] 10.2 Implement speaking activity tab: user's speaking events, self-rating breakdown, drill count
- [x] 10.3 Implement SRS tab: word state summary (counts by status), overdue count
- [x] 10.4 Implement exam history tab: all attempts for this user with score/pass/date
- [ ] 10.5 Add mini-charts to user detail (study event trend sparkline, rating distribution)

## 11. Enhanced Article Detail

- [x] 11.1 Add inline metadata editing (title, language, visibility) via PATCH API to article detail page
- [x] 11.2 Add processing job history section (from article_processing_jobs table)
- [x] 11.3 Add extracted workplace sentences section (from article_workplace_sentences join)

## 12. Final Verification

- [x] 12.1 Run `npm run build` — verify production build succeeds
- [x] 12.2 Run `npm run lint` — TypeScript strict mode passes in build; ESLint 9 requires config migration (non-blocking)
- [x] 12.3 Verify all new pages render without errors in dev mode
- [x] 12.4 Verify sidebar navigation groups render correctly
- [x] 12.5 Verify charts render with real data from database
- [x] 12.6 Build and push updated dashboard Docker image (`20260518.2322` — deployed to Z440, healthy)
