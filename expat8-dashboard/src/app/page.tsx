import { getAnalyticsKpis, getStudyEventTimeSeries, getPipelineHealth } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import ChartPanel from '@/components/ChartPanel';
import KpiCard from '@/components/charts/KpiCard';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';
import { formatSeconds } from '@/lib/format';

export const dynamic = 'force-dynamic';

export default async function HomePage() {
  const [kpis, timeSeries, pipeline] = await Promise.all([
    getAnalyticsKpis(),
    getStudyEventTimeSeries(30),
    getPipelineHealth(),
  ]);

  return (
    <PageShell title="Dashboard">
      <section className="kpi-grid">
        <KpiCard label="Total Users" value={kpis.totalUsers} />
        <KpiCard label="Active (7d)" value={kpis.activeUsers7d} accent />
        <KpiCard label="Events Today" value={kpis.studyEventsToday} />
        <KpiCard label="Total Events" value={kpis.totalStudyEvents} />
        <KpiCard label="Exam Pass Rate" value={`${kpis.examPassRate.toFixed(1)}%`} />
        <KpiCard label="Speaking Drills (7d)" value={kpis.speakingDrillsThisWeek} />
      </section>

      <div className="analytics-grid wide">
        <ChartPanel title="Daily Activity (30 days)">
          <TimeSeriesChart
            data={timeSeries}
            xKey="date"
            series={[
              { key: 'events', label: 'Study Events', color: '#2563eb' },
              { key: 'learners', label: 'Active Learners', color: '#059669' },
            ]}
          />
        </ChartPanel>

        <ChartPanel title="Pipeline Health">
          <div className="kpi-grid single-column">
            <KpiCard label="Jobs in Queue" value={pipeline.queueDepth} danger={pipeline.queueDepth > 10} />
            <KpiCard label="Failed (24h)" value={pipeline.failedLast24h} danger={pipeline.failedLast24h > 0} />
            <KpiCard label="P50 Duration (30d)" value={formatSeconds(pipeline.p50Seconds)} />
          </div>
        </ChartPanel>
      </div>
    </PageShell>
  );
}
