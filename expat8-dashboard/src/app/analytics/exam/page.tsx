import { Suspense } from 'react';

import { getExamAnalytics, getExamScoreDistribution, getExamTopicBreakdown } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import TimeRangeSelectorWrapper from '@/components/TimeRangeSelectorWrapper';
import KpiCard from '@/components/charts/KpiCard';
import BarChart from '@/components/charts/BarChart';
import { parseTimeRange, type TimeRange } from '@/lib/time-range';


export const dynamic = 'force-dynamic';

function parseRange(r: string | undefined): number {
  if (r === '7d') return 7;
  if (r === '90d') return 90;
  if (r === 'all') return 3650;
  return 30;
}

export default async function ExamAnalyticsPage({ searchParams }: { searchParams: Promise<{ range?: string }>; }) {
  const params = await searchParams;
  const range = params.range;
  const days = parseRange(range);
  const currentRange: TimeRange = parseTimeRange(range ?? null);

  const [analytics, scoreDistribution, topicBreakdown] = await Promise.all([
    getExamAnalytics(days),
    getExamScoreDistribution(days),
    getExamTopicBreakdown(days),
  ]);

  return (
    <PageShell
      title="Exam Analytics"
      actions={
        <Suspense>
          <TimeRangeSelectorWrapper current={currentRange} />
        </Suspense>
      }
    >
      <section className="kpi-grid">
        <KpiCard label="Total Attempts" value={analytics.total_attempts} />
        <KpiCard label="Pass Rate" value={`${analytics.pass_rate_pct.toFixed(1)}%`} accent />
        <KpiCard label="Avg Score" value={`${analytics.avg_score_pct.toFixed(1)}%`} />
      </section>

      <section className="analytics-grid wide">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Score Distribution</h2>
          </div>
          <BarChart
            data={scoreDistribution}
            xKey="bucket"
            series={[{ key: 'count', label: 'Attempts', color: '#2563eb' }]}
          />
        </div>

        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Topic Pass Rate</h2>
          </div>
          <BarChart
            data={topicBreakdown}
            xKey="topic"
            layout="vertical"
            series={[{ key: 'passRate', label: 'Pass Rate %', color: '#059669' }]}
          />
        </div>
      </section>

      <section className="table-panel">
        <h2>Topic Breakdown</h2>
        <table>
          <thead>
            <tr>
              <th>Topic</th>
              <th>Language</th>
              <th>Attempts</th>
              <th>Pass Rate</th>
              <th>Avg Score</th>
            </tr>
          </thead>
          <tbody>
            {topicBreakdown.length === 0 ? (
              <tr>
                <td colSpan={5}><div className="empty-state">No exam data available.</div></td>
              </tr>
            ) : topicBreakdown.map((row, i) => (
              <tr key={i}>
                <td data-label="Topic">{row.topic}</td>
                <td data-label="Language">{row.language}</td>
                <td data-label="Attempts">{row.attempts.toLocaleString()}</td>
                <td data-label="Pass Rate">{row.passRate.toFixed(1)}%</td>
                <td data-label="Avg Score">{row.avgScore.toFixed(1)}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </PageShell>
  );
}
