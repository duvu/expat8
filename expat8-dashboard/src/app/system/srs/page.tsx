import { getSrsStatusDistribution, getSrsOverdueCount } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import KpiCard from '@/components/charts/KpiCard';
import PieChart from '@/components/charts/PieChart';

export const dynamic = 'force-dynamic';

export default async function SrsBrowserPage() {
  const [distribution, overdueData] = await Promise.all([
    getSrsStatusDistribution(),
    getSrsOverdueCount(),
  ]);

  const slices = [
    { name: 'New', value: distribution.new ?? 0, color: '#94a3b8' },
    { name: 'Learning', value: distribution.learning ?? 0, color: '#d97706' },
    { name: 'Review', value: distribution.review ?? 0, color: '#2563eb' },
    { name: 'Completed', value: distribution.completed ?? 0, color: '#059669' },
  ];

  const totalWordStates = slices.reduce((sum, s) => sum + s.value, 0);

  return (
    <PageShell title="SRS Browser">
      <section className="kpi-grid">
        <KpiCard label="Total Word States" value={totalWordStates} />
        <KpiCard label="Overdue Count" value={overdueData.overdue_count} danger={overdueData.overdue_count > 0} />
      </section>

      <section className="analytics-grid">
        <div className="chart-panel">
          <div className="chart-panel-header">
            <h2 className="chart-panel-title">SRS Status Distribution</h2>
          </div>
          <PieChart data={slices} donut />
        </div>
      </section>
    </PageShell>
  );
}
