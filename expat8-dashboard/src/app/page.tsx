import { getAnalyticsKpis, getStudyEventTimeSeries, getPipelineHealth } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import KpiCard from '@/components/charts/KpiCard';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';

export const dynamic = 'force-dynamic';

export default async function HomePage() {
  const [kpis, timeSeries, pipeline] = await Promise.all([
    getAnalyticsKpis(),
    getStudyEventTimeSeries(30),
    getPipelineHealth(),
  ]);

  const passRateLabel = `${kpis.examPassRate.toFixed(1)}%`;
  const p50Label = pipeline.p50DurationSeconds != null ? `${pipeline.p50DurationSeconds.toFixed(1)}s` : '—';

  return (
    <PageShell title="Dashboard">
      {/* KPI row */}
      <section className="kpi-grid">
        <KpiCard label="Total Users" value={kpis.totalUsers} />
        <KpiCard label="Active (7d)" value={kpis.activeUsers7d} accent />
        <KpiCard label="Events Today" value={kpis.studyEventsToday} />
        <KpiCard label="Total Events" value={kpis.totalStudyEvents} />
        <KpiCard label="Exam Pass Rate" value={passRateLabel} />
        <KpiCard label="Speaking Drills (7d)" value={kpis.speakingDrillsThisWeek} />
      </section>

      {/* Activity chart */}
      <div className="analytics-grid wide">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Daily Activity (30 days)</h2>
          </div>
          <TimeSeriesChart
            data={timeSeries}
            xKey="date"
            series={[
              { key: 'events', label: 'Study Events', color: '#2563eb' },
              { key: 'learners', label: 'Active Learners', color: '#059669' },
            ]}
          />
        </div>

        {/* Pipeline health summary */}
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">Pipeline Health</h2>
          </div>
          <div className="kpi-grid" style={{ gridTemplateColumns: '1fr' }}>
            <KpiCard
              label="Jobs in Queue"
              value={pipeline.queue_depth}
              danger={pipeline.queue_depth > 10}
            />
            <KpiCard
              label="Failed (24h)"
              value={pipeline.failed_last_24h}
              danger={pipeline.failed_last_24h > 0}
            />
            <KpiCard label="P50 Duration" value={p50Label} />
          </div>
        </div>
      </div>
    </PageShell>
  );
}
