import {
  getWordTopicCoverage,
  getEntryTypeDistribution,
  getQualityScoreHistogram,
  getVocabReviewThroughput,
} from '@/lib/analytics';
import { resolveTimeRange } from '@/lib/time-range';
import ChartPanel from '@/components/ChartPanel';
import PageShell from '@/components/PageShell';
import TimeRangeSelector from '@/components/TimeRangeSelector';
import BarChart from '@/components/charts/BarChart';
import KpiCard from '@/components/charts/KpiCard';
import PieChart from '@/components/charts/PieChart';

export const dynamic = 'force-dynamic';

const ENTRY_TYPE_COLORS = ['#2563eb', '#7c3aed', '#d97706'];

export default async function ContentCoveragePage({ searchParams }: { searchParams: Promise<{ range?: string }> }) {
  const { range, days } = resolveTimeRange((await searchParams).range);
  const [topicCoverage, entryTypes, qualityHistogram, reviewThroughput] = await Promise.all([
    getWordTopicCoverage(),
    getEntryTypeDistribution(),
    getQualityScoreHistogram(),
    getVocabReviewThroughput(days),
  ]);

  const entryTypeSlices = entryTypes.map((e, i) => ({
    name: e.type,
    value: e.count,
    color: ENTRY_TYPE_COLORS[i % ENTRY_TYPE_COLORS.length],
  }));

  return (
    <PageShell title="Content Coverage" actions={<TimeRangeSelector current={range} />}>
      <section className="kpi-grid">
        <KpiCard label="Total Topics" value={topicCoverage.rows.length} />
        <KpiCard label="Total Words" value={topicCoverage.totalWords} />
        <KpiCard label="Entry Types" value={entryTypes.length} />
        <KpiCard label="Avg Quality Score" value={qualityHistogram.avgScore?.toFixed(2) ?? '—'} />
      </section>

      <section className="analytics-grid wide">
        <ChartPanel title="Topic Coverage">
          <BarChart
            data={topicCoverage.rows}
            xKey="topic"
            layout="vertical"
            series={[{ key: 'count', label: 'Words', color: '#2563eb' }]}
            height={320}
          />
        </ChartPanel>

        <ChartPanel title="Entry Type Distribution">
          <PieChart data={entryTypeSlices} donut />
        </ChartPanel>
      </section>

      <section className="analytics-grid wide">
        <ChartPanel title="Quality Score Histogram">
          <BarChart
            data={qualityHistogram.rows}
            xKey="bucket"
            series={[{ key: 'count', label: 'Words', color: '#7c3aed' }]}
          />
        </ChartPanel>

        <ChartPanel title="Review Throughput">
          <BarChart
            data={reviewThroughput}
            xKey="date"
            stacked
            series={[
              { key: 'approved', label: 'Approved', color: '#059669' },
              { key: 'rejected', label: 'Rejected', color: '#dc2626' },
            ]}
          />
        </ChartPanel>
      </section>
    </PageShell>
  );
}
