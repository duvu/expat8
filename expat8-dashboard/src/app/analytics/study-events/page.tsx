import { getStudyEventTimeSeries, getStudyEventsByRating, getActiveUserMetrics } from '@/lib/analytics';
import { resolveTimeRange } from '@/lib/time-range';
import ChartPanel from '@/components/ChartPanel';
import PageShell from '@/components/PageShell';
import TimeRangeSelector from '@/components/TimeRangeSelector';
import BarChart from '@/components/charts/BarChart';
import KpiCard from '@/components/charts/KpiCard';
import KpiGrid from '@/components/charts/KpiGrid';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';
import { CHART } from '@/lib/chart-colors';

export const metadata = { title: 'Study events' };
export const dynamic = 'force-dynamic';

export default async function StudyEventsPage({ searchParams }: { searchParams: Promise<{ range?: string }> }) {
  const { range, days } = resolveTimeRange((await searchParams).range);
  const [timeSeries, ratingData, activeUsers] = await Promise.all([
    getStudyEventTimeSeries(days),
    getStudyEventsByRating(days),
    getActiveUserMetrics(),
  ]);

  return (
    <PageShell title="Study events" description="How many cards learners review, and how they rate them." actions={<TimeRangeSelector current={range} />}>
      <KpiGrid>
        <KpiCard label="Daily active users" value={activeUsers.dau} sub="DAU, since midnight UTC" icon="activity" />
        <KpiCard label="Weekly active users" value={activeUsers.wau} sub="WAU, last 7 days" icon="activity" />
        <KpiCard label="Monthly active users" value={activeUsers.mau} sub="MAU, last 30 days" icon="activity" />
      </KpiGrid>

      <section className="analytics-grid wide">
        <ChartPanel title="Daily events and learners">
          <TimeSeriesChart
            data={timeSeries}
            xKey="date"
            series={[
              { key: 'events', label: 'Events', color: CHART.primary },
              { key: 'learners', label: 'Learners', color: CHART.progress },
            ]}
          />
        </ChartPanel>

        <ChartPanel title="Rating distribution" description="Learner self-ratings per day">
          <BarChart
            data={ratingData}
            xKey="date"
            stacked
            series={[
              { key: 'easy', label: 'Easy', color: CHART.progress },
              { key: 'too_easy', label: 'Too easy', color: CHART.primary },
              { key: 'hard', label: 'Hard', color: CHART.attention },
              { key: 'too_hard', label: 'Too hard', color: CHART.danger },
            ]}
          />
        </ChartPanel>
      </section>
    </PageShell>
  );
}
