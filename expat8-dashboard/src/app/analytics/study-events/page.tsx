import { getStudyEventTimeSeries, getStudyEventsByRating, getActiveUserMetrics } from '@/lib/analytics';
import { resolveTimeRange } from '@/lib/time-range';
import ChartPanel from '@/components/ChartPanel';
import PageShell from '@/components/PageShell';
import TimeRangeSelector from '@/components/TimeRangeSelector';
import BarChart from '@/components/charts/BarChart';
import KpiCard from '@/components/charts/KpiCard';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';

export const dynamic = 'force-dynamic';

export default async function StudyEventsPage({ searchParams }: { searchParams: Promise<{ range?: string }> }) {
  const { range, days } = resolveTimeRange((await searchParams).range);
  const [timeSeries, ratingData, activeUsers] = await Promise.all([
    getStudyEventTimeSeries(days),
    getStudyEventsByRating(days),
    getActiveUserMetrics(),
  ]);

  return (
    <PageShell title="Study Events Analytics" actions={<TimeRangeSelector current={range} />}>
      <section className="kpi-grid">
        <KpiCard label="DAU" value={activeUsers.dau} />
        <KpiCard label="WAU" value={activeUsers.wau} />
        <KpiCard label="MAU" value={activeUsers.mau} />
      </section>

      <section className="analytics-grid wide">
        <ChartPanel title="Daily Events & Learners">
          <TimeSeriesChart
            data={timeSeries}
            xKey="date"
            series={[
              { key: 'events', label: 'Events', color: '#2563eb' },
              { key: 'learners', label: 'Learners', color: '#059669' },
            ]}
          />
        </ChartPanel>

        <ChartPanel title="Rating Distribution">
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
        </ChartPanel>
      </section>
    </PageShell>
  );
}
