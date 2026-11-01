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
import KpiGrid from '@/components/charts/KpiGrid';
import PieChart from '@/components/charts/PieChart';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';
import { CHART } from '@/lib/chart-colors';

export const metadata = { title: 'Speaking analytics' };
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
    { name: 'Clear', value: selfRatings.clear, color: CHART.progress },
    { name: 'Hesitated', value: selfRatings.hesitated, color: CHART.attention },
    { name: 'Could not say', value: selfRatings.could_not_say, color: CHART.danger },
  ];

  return (
    <PageShell title="Speaking analytics" description="Speaking drills, completion and self-ratings." actions={<TimeRangeSelector current={range} />}>
      <KpiGrid>
        <KpiCard label="Drills completed" value={drillStats.completed} sub="in the selected period" icon="mic" />
        <KpiCard label="Completion rate" value={`${drillStats.completionRatePct.toFixed(1)}%`} sub="drills finished" icon="check" />
        <KpiCard label="Average duration" value={`${drillStats.avgDurationSeconds.toFixed(1)}s`} sub="per drill" icon="clock" />
        <KpiCard label="Prompt coverage" value={`${promptCoverage.coveragePct.toFixed(1)}%`} sub="prompts with activity" icon="chat" />
      </KpiGrid>

      <section className="analytics-grid wide">
        <ChartPanel title="Speaking event volume" description="Events per day">
          <TimeSeriesChart data={timeSeries} xKey="date" series={[{ key: 'events', label: 'Events', color: CHART.primary }]} />
        </ChartPanel>

        <ChartPanel title="Self-rating distribution">
          <PieChart data={ratingSlices} donut />
        </ChartPanel>
      </section>
    </PageShell>
  );
}
