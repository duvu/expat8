import { Suspense } from 'react';

import { getStudyEventTimeSeries, getStudyEventsByRating, getActiveUserMetrics } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import TimeRangeSelectorWrapper from '@/components/TimeRangeSelectorWrapper';
import KpiCard from '@/components/charts/KpiCard';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';
import BarChart from '@/components/charts/BarChart';
import { parseTimeRange, type TimeRange } from '@/lib/time-range';


export const dynamic = 'force-dynamic';

function parseRange(r: string | undefined): number {
  if (r === '7d') return 7;
  if (r === '90d') return 90;
  if (r === 'all') return 3650;
  return 30;
}

export default async function StudyEventsPage({ searchParams }: { searchParams: Promise<{ range?: string }>; }) {
  const params = await searchParams;
  const range = params.range;
  const days = parseRange(range);
  const currentRange: TimeRange = parseTimeRange(range ?? null);

  const [timeSeries, ratingData, activeUsers] = await Promise.all([
    getStudyEventTimeSeries(days),
    getStudyEventsByRating(days),
    getActiveUserMetrics(),
  ]);

  return (
    <PageShell
      title="Study Events Analytics"
      actions={
        <Suspense>
          <TimeRangeSelectorWrapper current={currentRange} />
        </Suspense>
      }
    >
      <section className="kpi-grid">
        <KpiCard label="DAU" value={activeUsers.dau} />
        <KpiCard label="WAU" value={activeUsers.wau} />
        <KpiCard label="MAU" value={activeUsers.mau} />
      </section>

      <section className="analytics-grid wide">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Daily Events &amp; Learners</h2>
          </div>
          <TimeSeriesChart
            data={timeSeries}
            xKey="date"
            series={[
              { key: 'events', label: 'Events', color: '#2563eb' },
              { key: 'learners', label: 'Learners', color: '#059669' },
            ]}
          />
        </div>

        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Rating Distribution</h2>
          </div>
          <BarChart
            data={ratingData}
            xKey="date"
            stacked
            series={[
              { key: 'easy', label: 'Easy', color: '#059669' },
              { key: 'too_easy', label: 'Too Easy', color: '#0d9488' },
              { key: 'hard', label: 'Hard', color: '#d97706' },
              { key: 'too_hard', label: 'Too Hard', color: '#dc2626' },
            ]}
          />
        </div>
      </section>
    </PageShell>
  );
}
