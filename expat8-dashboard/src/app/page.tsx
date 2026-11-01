import { getAnalyticsKpis, getStudyEventTimeSeries, getPipelineHealth } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import ChartPanel from '@/components/ChartPanel';
import KpiCard from '@/components/charts/KpiCard';
import KpiGrid from '@/components/charts/KpiGrid';
import TimeSeriesChart from '@/components/charts/TimeSeriesChart';
import { formatSeconds } from '@/lib/format';
import { CHART } from '@/lib/chart-colors';

export const metadata = { title: 'Dashboard' };
export const dynamic = 'force-dynamic';

export default async function HomePage() {
  const [kpis, timeSeries, pipeline] = await Promise.all([
    getAnalyticsKpis(),
    getStudyEventTimeSeries(30),
    getPipelineHealth(),
  ]);

  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const yesterdayEvents = timeSeries.find((point) => point.date === yesterday)?.events ?? (timeSeries.length > 0 ? 0 : null);

  return (
    <PageShell title="Dashboard" description="Learning activity, exam results and content pipeline health at a glance.">
      <KpiGrid>
        <KpiCard label="Total users" value={kpis.totalUsers} sub="registered accounts" icon="users" />
        <KpiCard label="Active learners" value={kpis.activeUsers7d} sub={`last 7 days, of ${kpis.totalUsers.toLocaleString('en-US')} users`} icon="activity" />
        <KpiCard label="Events today" value={kpis.studyEventsToday} sub={yesterdayEvents == null ? 'since midnight UTC' : `${yesterdayEvents.toLocaleString('en-US')} yesterday`} icon="chart" />
        <KpiCard label="Total events" value={kpis.totalStudyEvents} sub="all time" icon="layers" />
        <KpiCard label="Exam pass rate" value={`${kpis.examPassRate.toFixed(1)}%`} sub="all attempts" icon="award" />
        <KpiCard label="Speaking drills" value={kpis.speakingDrillsThisWeek} sub="completed, last 7 days" icon="mic" />
      </KpiGrid>

      <div className="analytics-grid wide">
        <ChartPanel title="Daily activity" description="Study events and active learners, last 30 days">
          <TimeSeriesChart
            data={timeSeries}
            xKey="date"
            series={[
              { key: 'events', label: 'Study events', color: CHART.primary },
              { key: 'learners', label: 'Active learners', color: CHART.progress },
            ]}
          />
        </ChartPanel>

        <ChartPanel title="Pipeline health" description="Article processing queue">
          <KpiGrid stacked>
            <KpiCard label="Jobs in queue" value={pipeline.queueDepth} sub={pipeline.queueDepth > 10 ? 'backlog building up' : 'waiting for the worker'} tone={pipeline.queueDepth > 10 ? 'attention' : undefined} />
            <KpiCard label="Failed jobs" value={pipeline.failedLast24h} sub={pipeline.failedLast24h > 0 ? 'last 24 hours, needs attention' : 'none in the last 24 hours'} tone={pipeline.failedLast24h > 0 ? 'danger' : 'positive'} />
            <KpiCard label="Median duration" value={formatSeconds(pipeline.p50Seconds)} sub="per job, last 30 days" />
          </KpiGrid>
        </ChartPanel>
      </div>
    </PageShell>
  );
}
