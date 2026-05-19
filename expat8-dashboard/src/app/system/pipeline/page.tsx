import { getPipelineHealth, getArticleStatusCounts, getProcessingJobStats, getGenerationRuns } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import KpiCard from '@/components/charts/KpiCard';
import BarChart from '@/components/charts/BarChart';

export const dynamic = 'force-dynamic';

export default async function PipelineMonitorPage() {
  const [health, statusCounts, jobStats, generationRuns] = await Promise.all([
    getPipelineHealth(),
    getArticleStatusCounts(),
    getProcessingJobStats(),
    getGenerationRuns(),
  ]);

  return (
    <PageShell title="Pipeline Monitor">
      <section className="kpi-grid">
        <KpiCard label="Queue Depth" value={health.queue_depth} danger={health.queue_depth > 50} />
        <KpiCard label="Failed (24h)" value={health.failed_last_24h} danger={health.failed_last_24h > 0} />
        <KpiCard label="P50 Duration" value={`${jobStats.p50_duration_s.toFixed(1)}s`} />
      </section>

      <section className="analytics-grid">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Article Status Counts</h2>
          </div>
          <BarChart
            data={statusCounts}
            xKey="status"
            series={[{ key: 'count', label: 'Articles', color: '#2563eb' }]}
          />
        </div>
      </section>

      <section className="table-panel">
        <h2>Generation Runs</h2>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Status</th>
              <th>Requested</th>
              <th>Inserted</th>
              <th>Duration</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            {generationRuns.length === 0 ? (
              <tr>
                <td colSpan={6}><div className="empty-state">No generation runs found.</div></td>
              </tr>
            ) : generationRuns.map((run) => (
              <tr key={run.id}>
                <td data-label="ID"><span title={run.id}>{run.id.slice(0, 8)}…</span></td>
                <td data-label="Status"><span className="badge" data-status={run.status}>{run.status}</span></td>
                <td data-label="Requested">{run.requested_count.toLocaleString()}</td>
                <td data-label="Inserted">{run.inserted_count.toLocaleString()}</td>
                <td data-label="Duration">{run.duration_s != null ? `${run.duration_s.toFixed(1)}s` : '—'}</td>
                <td data-label="Error">{run.error ?? <span className="muted">—</span>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </PageShell>
  );
}
