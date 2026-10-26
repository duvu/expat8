import { getExamAnalytics, getExamScoreDistribution, getExamTopicBreakdown } from '@/lib/analytics';
import { resolveTimeRange } from '@/lib/time-range';
import ChartPanel from '@/components/ChartPanel';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';
import TimeRangeSelector from '@/components/TimeRangeSelector';
import BarChart from '@/components/charts/BarChart';
import KpiCard from '@/components/charts/KpiCard';

export const dynamic = 'force-dynamic';

export default async function ExamAnalyticsPage({ searchParams }: { searchParams: Promise<{ range?: string }> }) {
  const { range, days } = resolveTimeRange((await searchParams).range);
  const [analytics, scoreDistribution, topicBreakdown] = await Promise.all([
    getExamAnalytics(days),
    getExamScoreDistribution(days),
    getExamTopicBreakdown(days),
  ]);

  return (
    <PageShell title="Exam Analytics" actions={<TimeRangeSelector current={range} />}>
      <section className="kpi-grid">
        <KpiCard label="Total Attempts" value={analytics.totalAttempts} />
        <KpiCard label="Pass Rate" value={`${analytics.passRatePct.toFixed(1)}%`} accent />
        <KpiCard label="Avg Score" value={`${analytics.avgScorePct.toFixed(1)}%`} />
      </section>

      <section className="analytics-grid wide">
        <ChartPanel title="Score Distribution">
          <BarChart
            data={scoreDistribution}
            xKey="bucket"
            series={[{ key: 'count', label: 'Attempts', color: '#2563eb' }]}
          />
        </ChartPanel>

        <ChartPanel title="Topic Pass Rate">
          <BarChart
            data={topicBreakdown}
            xKey="topic"
            layout="vertical"
            series={[{ key: 'passRate', label: 'Pass Rate %', color: '#059669' }]}
          />
        </ChartPanel>
      </section>

      <section className="table-panel">
        <h2>Topic Breakdown</h2>
        <DataTable
          rows={topicBreakdown}
          rowKey={(row) => `${row.topic}:${row.language}`}
          empty="No exam data available."
          columns={[
            { label: 'Topic', render: (row) => row.topic },
            { label: 'Language', render: (row) => row.language },
            { label: 'Attempts', render: (row) => row.attempts.toLocaleString() },
            { label: 'Pass Rate', render: (row) => `${row.passRate.toFixed(1)}%` },
            { label: 'Avg Score', render: (row) => `${row.avgScore.toFixed(1)}%` },
          ]}
        />
      </section>
    </PageShell>
  );
}
