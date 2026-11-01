import { getPipelineHealth, getArticleStatusCounts, getGenerationRuns } from '@/lib/analytics';
import { formatSeconds, truncate } from '@/lib/format';
import ChartPanel from '@/components/ChartPanel';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';
import StatusBadge from '@/components/StatusBadge';
import BarChart from '@/components/charts/BarChart';
import KpiCard from '@/components/charts/KpiCard';
import KpiGrid from '@/components/charts/KpiGrid';
import { CHART } from '@/lib/chart-colors';

export const metadata = { title: 'Pipeline' };
export const dynamic = 'force-dynamic';

export default async function PipelineMonitorPage() {
  const [health, statusCounts, generationRuns] = await Promise.all([
    getPipelineHealth(),
    getArticleStatusCounts(),
    getGenerationRuns(),
  ]);

  return (
    <PageShell title="Pipeline" description="Article processing queue, failures and generation runs.">
      <KpiGrid>
        <KpiCard label="Queue depth" value={health.queueDepth} sub="jobs waiting for the worker" icon="pipeline" tone={health.queueDepth > 50 ? 'attention' : undefined} />
        <KpiCard label="Failed jobs" value={health.failedLast24h} sub={health.failedLast24h > 0 ? 'last 24 hours, needs attention' : 'none in the last 24 hours'} icon="alert" tone={health.failedLast24h > 0 ? 'danger' : 'positive'} />
        <KpiCard label="Median duration" value={formatSeconds(health.p50Seconds)} sub="per job, last 30 days" icon="clock" />
      </KpiGrid>

      <section className="analytics-grid">
        <ChartPanel title="Articles by status" description="Current processing state">
          <BarChart data={statusCounts} xKey="status" series={[{ key: 'count', label: 'Articles', color: CHART.primary }]} />
        </ChartPanel>
      </section>

      <section className="table-panel">
        <h2>Generation runs</h2>
        <DataTable
          rows={generationRuns}
          rowKey={(run) => run.id}
          empty="No generation runs found."
          noun="runs"
          columns={[
            { label: 'ID', render: (run) => <span title={run.id}>{truncate(run.id, 8)}</span> },
            { label: 'Status', render: (run) => <StatusBadge status={run.status} /> },
            { label: 'Requested', numeric: true, render: (run) => run.requested_count.toLocaleString() },
            { label: 'Inserted', numeric: true, render: (run) => run.inserted_count.toLocaleString() },
            { label: 'Duration', numeric: true, render: (run) => formatSeconds(run.duration_s) },
            { label: 'Error', render: (run) => run.error ?? <span className="muted">—</span> },
          ]}
        />
      </section>
    </PageShell>
  );
}
