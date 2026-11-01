import { getExamAnalytics, getExamScoreDistribution, getExamTopicBreakdown } from '@/lib/analytics';
import { resolveTimeRange } from '@/lib/time-range';
import ChartPanel from '@/components/ChartPanel';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';
import TimeRangeSelector from '@/components/TimeRangeSelector';
import BarChart from '@/components/charts/BarChart';
import LanguageChip from '@/components/LanguageChip';
import KpiCard from '@/components/charts/KpiCard';
import KpiGrid from '@/components/charts/KpiGrid';
import { CHART } from '@/lib/chart-colors';

export const metadata = { title: 'Exam analytics' };
export const dynamic = 'force-dynamic';

export default async function ExamAnalyticsPage({ searchParams }: { searchParams: Promise<{ range?: string }> }) {
  const { range, days } = resolveTimeRange((await searchParams).range);
  const [analytics, scoreDistribution, topicBreakdown] = await Promise.all([
    getExamAnalytics(days),
    getExamScoreDistribution(days),
    getExamTopicBreakdown(days),
  ]);

  return (
    <PageShell title="Exam analytics" description="Attempts, scores and pass rates by topic." actions={<TimeRangeSelector current={range} />}>
      <KpiGrid>
        <KpiCard label="Total attempts" value={analytics.totalAttempts} sub="in the selected period" icon="list" />
        <KpiCard label="Pass rate" value={`${analytics.passRatePct.toFixed(1)}%`} sub="attempts that passed" icon="award" />
        <KpiCard label="Average score" value={`${analytics.avgScorePct.toFixed(1)}%`} sub="across all attempts" icon="chart" />
      </KpiGrid>

      <section className="analytics-grid wide">
        <ChartPanel title="Score distribution" description="Attempts per score band">
          <BarChart
            data={scoreDistribution}
            xKey="bucket"
            series={[{ key: 'count', label: 'Attempts', color: CHART.primary }]}
          />
        </ChartPanel>

        <ChartPanel title="Pass rate by topic" description="Percent of attempts that passed">
          <BarChart
            data={topicBreakdown}
            xKey="topic"
            layout="vertical"
            series={[{ key: 'passRate', label: 'Pass Rate %', color: CHART.progress }]}
          />
        </ChartPanel>
      </section>

      <section className="table-panel">
        <h2>Topic breakdown</h2>
        <DataTable
          rows={topicBreakdown}
          rowKey={(row) => `${row.topic}:${row.language}`}
          empty="No exam data available."
          noun="topics"
          columns={[
            { label: 'Topic', render: (row) => row.topic },
            { label: 'Language', render: (row) => <LanguageChip code={row.language} /> },
            { label: 'Attempts', numeric: true, render: (row) => row.attempts.toLocaleString() },
            { label: 'Pass rate', numeric: true, render: (row) => `${row.passRate.toFixed(1)}%` },
            { label: 'Avg score', numeric: true, render: (row) => `${row.avgScore.toFixed(1)}%` },
          ]}
        />
      </section>
    </PageShell>
  );
}
