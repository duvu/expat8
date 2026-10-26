import {
  getSpeakingEventTimeSeries,
  getSpeakingSelfRatingDistribution,
  getSpeakingDrillStats,
  getSpeakingPromptCoverage,
} from '@/lib/analytics';
import { resolveTimeRange } from '@/lib/time-range';
import ChartPanel from '@/components/ChartPanel';
import PageShell from '@/components/PageShell';
import TimeRangeSelector from '@/components/TimeRangeSelector';
import KpiCard from '@/components/charts/KpiCard';
import PieChart from '@/components/charts/PieChart';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';

export const dynamic = 'force-dynamic';

export default async function SpeakingAnalyticsPage({ searchParams }: { searchParams: Promise<{ range?: string }> }) {
  const { range, days } = resolveTimeRange((await searchParams).range);
  const [timeSeries, selfRatings, drillStats, promptCoverage] = await Promise.all([
    getSpeakingEventTimeSeries(days),
    getSpeakingSelfRatingDistribution(days),
    getSpeakingDrillStats(days),
    getSpeakingPromptCoverage(),
  ]);

  const ratingSlices = [
    { name: 'Clear', value: selfRatings.clear, color: '#059669' },
    { name: 'Hesitated', value: selfRatings.hesitated, color: '#d97706' },
    { name: 'Could Not Say', value: selfRatings.could_not_say, color: '#dc2626' },
  ];

  return (
    <PageShell title="Speaking Analytics" actions={<TimeRangeSelector current={range} />}>
      <section className="kpi-grid">
        <KpiCard label="Total Drills Completed" value={drillStats.completed} />
        <KpiCard label="Completion Rate" value={`${drillStats.completionRatePct.toFixed(1)}%`} accent />
        <KpiCard label="Avg Duration" value={`${drillStats.avgDurationSeconds.toFixed(1)}s`} />
        <KpiCard label="Prompt Coverage" value={`${promptCoverage.coveragePct.toFixed(1)}%`} />
      </section>

      <section className="analytics-grid wide">
        <ChartPanel title="Speaking Event Volume">
          <TimeSeriesChart data={timeSeries} xKey="date" series={[{ key: 'events', label: 'Events', color: '#2563eb' }]} />
        </ChartPanel>

        <ChartPanel title="Self-Rating Distribution">
          <PieChart data={ratingSlices} donut />
        </ChartPanel>
      </section>
    </PageShell>
  );
}
