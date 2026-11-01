import {
  getWordTopicCoverage,
  getEntryTypeDistribution,
  getQualityScoreHistogram,
  getWordsAddedPerDay,
} from '@/lib/analytics';
import { resolveTimeRange } from '@/lib/time-range';
import ChartPanel from '@/components/ChartPanel';
import PageShell from '@/components/PageShell';
import TimeRangeSelector from '@/components/TimeRangeSelector';
import BarChart from '@/components/charts/BarChart';
import KpiCard from '@/components/charts/KpiCard';
import KpiGrid from '@/components/charts/KpiGrid';
import PieChart from '@/components/charts/PieChart';
import { CHART } from '@/lib/chart-colors';

export const metadata = { title: 'Content coverage' };
export const dynamic = 'force-dynamic';

const ENTRY_TYPE_COLORS = [CHART.primary, CHART.info, CHART.attention];

export default async function ContentCoveragePage({ searchParams }: { searchParams: Promise<{ range?: string }> }) {
  const { range, days } = resolveTimeRange((await searchParams).range);
  const [topicCoverage, entryTypes, qualityHistogram, wordsAdded] = await Promise.all([
    getWordTopicCoverage(),
    getEntryTypeDistribution(),
    getQualityScoreHistogram(),
    getWordsAddedPerDay(days),
  ]);

  const entryTypeSlices = entryTypes.map((e, i) => ({
    name: e.type,
    value: e.count,
    color: ENTRY_TYPE_COLORS[i % ENTRY_TYPE_COLORS.length],
  }));

  return (
    <PageShell title="Content coverage" description="Vocabulary breadth by topic, entry type and quality." actions={<TimeRangeSelector current={range} />}>
      <KpiGrid>
        <KpiCard label="Topics" value={topicCoverage.rows.length} sub="with vocabulary" icon="layers" />
        <KpiCard label="Words" value={topicCoverage.totalWords} sub="across all topics" icon="book" />
        <KpiCard label="Entry types" value={entryTypes.length} sub="kinds of entry" icon="list" />
        <KpiCard label="Average quality" value={qualityHistogram.avgScore?.toFixed(2) ?? '—'} sub="score per word" icon="award" />
      </KpiGrid>

      <section className="analytics-grid wide">
        <ChartPanel title="Topic coverage" description="Words per topic">
          <BarChart
            data={topicCoverage.rows}
            xKey="topic"
            layout="vertical"
            series={[{ key: 'count', label: 'Words', color: CHART.primary }]}
            height={320}
          />
        </ChartPanel>

        <ChartPanel title="Entry types">
          <PieChart data={entryTypeSlices} donut />
        </ChartPanel>
      </section>

      <section className="analytics-grid wide">
        <ChartPanel title="Quality scores" description="Words per score band">
          <BarChart
            data={qualityHistogram.rows}
            xKey="bucket"
            series={[{ key: 'count', label: 'Words', color: CHART.info }]}
          />
        </ChartPanel>

        <ChartPanel title="Words added" description="New study words per day">
          <BarChart
            data={wordsAdded}
            xKey="date"
            series={[{ key: 'words', label: 'Words', color: CHART.progress }]}
          />
        </ChartPanel>
      </section>
    </PageShell>
  );
}
