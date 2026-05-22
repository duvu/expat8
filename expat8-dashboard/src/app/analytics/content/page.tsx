import { Suspense } from 'react';

import {
  getWordTopicCoverage,
  getEntryTypeDistribution,
  getQualityScoreHistogram,
  getVocabReviewThroughput,
} from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import TimeRangeSelectorWrapper from '@/components/TimeRangeSelectorWrapper';
import KpiCard from '@/components/charts/KpiCard';
import BarChart from '@/components/charts/BarChart';
import PieChart from '@/components/charts/PieChart';
import { parseTimeRange, type TimeRange } from '@/lib/time-range';


export const dynamic = 'force-dynamic';

function parseRange(r: string | undefined): number {
  if (r === '7d') return 7;
  if (r === '90d') return 90;
  if (r === 'all') return 3650;
  return 30;
}

export default async function ContentCoveragePage({ searchParams }: { searchParams: Promise<{ range?: string }>; }) {
  const params = await searchParams;
  const range = params.range;
  const days = parseRange(range);
  const currentRange: TimeRange = parseTimeRange(range ?? null);

  const [topicCoverage, entryTypes, qualityHistogram, reviewThroughput] = await Promise.all([
    getWordTopicCoverage(),
    getEntryTypeDistribution(),
    getQualityScoreHistogram(),
    getVocabReviewThroughput(days),
  ]);

  const entryTypeSlices = entryTypes.map((e: { type: string; count: number }, i: number) => ({
    name: e.type,
    value: e.count,
    color: ['#2563eb', '#7c3aed', '#d97706'][i % 3],
  }));

  return (
    <PageShell
      title="Content Coverage"
      actions={
        <Suspense>
          <TimeRangeSelectorWrapper current={currentRange} />
        </Suspense>
      }
    >
      <section className="kpi-grid">
        <KpiCard label="Total Topics" value={topicCoverage.total_topics} />
        <KpiCard label="Total Words" value={topicCoverage.total_words} />
        <KpiCard label="Entry Types" value={entryTypes.length} />
        <KpiCard label="Avg Quality Score" value={qualityHistogram.avg_score?.toFixed(2) ?? '—'} />
      </section>

      <section className="analytics-grid wide">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Topic Coverage</h2>
          </div>
          <BarChart
            data={topicCoverage.rows}
            xKey="topic"
            layout="vertical"
            series={[{ key: 'count', label: 'Words', color: '#2563eb' }]}
            height={320}
          />
        </div>

        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Entry Type Distribution</h2>
          </div>
          <PieChart data={entryTypeSlices} donut />
        </div>
      </section>

      <section className="analytics-grid wide">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Quality Score Histogram</h2>
          </div>
          <BarChart
            data={qualityHistogram.rows}
            xKey="bucket"
            series={[{ key: 'count', label: 'Words', color: '#7c3aed' }]}
          />
        </div>

        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Review Throughput</h2>
          </div>
          <BarChart
            data={reviewThroughput}
            xKey="date"
            stacked
            series={[
              { key: 'approved', label: 'Approved', color: '#059669' },
              { key: 'rejected', label: 'Rejected', color: '#dc2626' },
            ]}
          />
        </div>
      </section>
    </PageShell>
  );
}
