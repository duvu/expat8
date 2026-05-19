import { Suspense } from 'react';

import {
  getSpeakingEventTimeSeries,
  getSpeakingSelfRatingDistribution,
  getSpeakingDrillStats,
  getSpeakingPromptCoverage,
} from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import TimeRangeSelectorWrapper from '@/components/TimeRangeSelectorWrapper';
import KpiCard from '@/components/charts/KpiCard';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';
import PieChart from '@/components/charts/PieChart';
import { parseTimeRange, type TimeRange } from '@/lib/time-range';


export const dynamic = 'force-dynamic';

function parseRange(r: string | undefined): number {
  if (r === '7d') return 7;
  if (r === '90d') return 90;
  if (r === 'all') return 3650;
  return 30;
}

export default async function SpeakingAnalyticsPage({ searchParams }: { searchParams: Promise<{ range?: string }>; }) {
  const params = await searchParams;
  const range = params.range;
  const days = parseRange(range);
  const currentRange: TimeRange = parseTimeRange(range ?? null);

  const [timeSeries, selfRatings, drillStats, promptCoverage] = await Promise.all([
    getSpeakingEventTimeSeries(days),
    getSpeakingSelfRatingDistribution(days),
    getSpeakingDrillStats(days),
    getSpeakingPromptCoverage(),
  ]);

  const ratingSlices = [
    { name: 'Clear', value: selfRatings.clear ?? 0, color: '#059669' },
    { name: 'Hesitated', value: selfRatings.hesitated ?? 0, color: '#d97706' },
    { name: 'Could Not Say', value: selfRatings.could_not_say ?? 0, color: '#dc2626' },
  ];

  return (
    <PageShell
      title="Speaking Analytics"
      actions={
        <Suspense>
          <TimeRangeSelectorWrapper current={currentRange} />
        </Suspense>
      }
    >
      <section className="kpi-grid">
        <KpiCard label="Total Drills Completed" value={drillStats.total_completed} />
        <KpiCard label="Completion Rate" value={`${drillStats.completion_rate_pct.toFixed(1)}%`} accent />
        <KpiCard label="Avg Duration" value={`${drillStats.avg_duration_s.toFixed(1)}s`} />
        <KpiCard label="Prompt Coverage" value={`${promptCoverage.coverage_pct.toFixed(1)}%`} />
      </section>

      <section className="analytics-grid wide">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Speaking Event Volume</h2>
          </div>
          <TimeSeriesChart
            data={timeSeries}
            xKey="date"
            series={[
              { key: 'events', label: 'Events', color: '#2563eb' },
            ]}
          />
        </div>

        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Self-Rating Distribution</h2>
          </div>
          <PieChart data={ratingSlices} donut />
        </div>
      </section>
    </PageShell>
  );
}
