import { getPipelineHealth, getArticleStatusCounts, getGenerationRuns } from '@/lib/analytics';
import { formatSeconds, truncate } from '@/lib/format';
import ChartPanel from '@/components/ChartPanel';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';
import StatusBadge from '@/components/StatusBadge';
import BarChart from '@/components/charts/BarChart';
import KpiCard from '@/components/charts/KpiCard';

export const dynamic = 'force-dynamic';

export default async function PipelineMonitorPage() {
  const [health, statusCounts, generationRuns] = await Promise.all([
    getPipelineHealth(),
    getArticleStatusCounts(),
    getGenerationRuns(),
  ]);

  return (
    <PageShell title="Pipeline Monitor">
      <section className="kpi-grid">
        <KpiCard label="Queue Depth" value={health.queueDepth} danger={health.queueDepth > 50} />
        <KpiCard label="Failed (24h)" value={health.failedLast24h} danger={health.failedLast24h > 0} />
        <KpiCard label="P50 Duration (30d)" value={formatSeconds(health.p50Seconds)} />
      </section>

      <section className="analytics-grid">
        <ChartPanel title="Article Status Counts">
          <BarChart data={statusCounts} xKey="status" series={[{ key: 'count', label: 'Articles', color: '#2563eb' }]} />
        </ChartPanel>
      </section>

      <section className="table-panel">
        <h2>Generation Runs</h2>
        <DataTable
          rows={generationRuns}
          rowKey={(run) => run.id}
          empty="No generation runs found."
          columns={[
            { label: 'ID', render: (run) => <span title={run.id}>{truncate(run.id, 8)}</span> },
            { label: 'Status', render: (run) => <StatusBadge status={run.status} /> },
            { label: 'Requested', render: (run) => run.requested_count.toLocaleString() },
            { label: 'Inserted', render: (run) => run.inserted_count.toLocaleString() },
            { label: 'Duration', render: (run) => formatSeconds(run.duration_s) },
            { label: 'Error', render: (run) => run.error ?? <span className="muted">—</span> },
          ]}
        />
      </section>
    </PageShell>
  );
}
