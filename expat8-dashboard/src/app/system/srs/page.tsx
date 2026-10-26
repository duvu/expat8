import { getSrsOverview } from '@/lib/analytics';
import ChartPanel from '@/components/ChartPanel';
import PageShell from '@/components/PageShell';
import KpiCard from '@/components/charts/KpiCard';
import PieChart from '@/components/charts/PieChart';

export const dynamic = 'force-dynamic';

// Statuses written by the backend SRS scheduler (backend/src/domain/srs.js); `completed` is the
// pre-SRS name for words that left the review cycle and counts as mastered.
const STATUS_SLICES = [
  { statuses: ['learning'], name: 'Learning', color: '#d97706' },
  { statuses: ['review'], name: 'Review', color: '#2563eb' },
  { statuses: ['mastered', 'completed'], name: 'Mastered', color: '#059669' },
];

export default async function SrsBrowserPage() {
  const { byStatus, overdue } = await getSrsOverview();
  const slices = STATUS_SLICES.map(({ statuses, name, color }) => ({
    name,
    color,
    value: statuses.reduce((sum, status) => sum + (byStatus[status] ?? 0), 0),
  }));
  const totalWordStates = slices.reduce((sum, s) => sum + s.value, 0);

  return (
    <PageShell title="SRS Browser">
      <section className="kpi-grid">
        <KpiCard label="Total Word States" value={totalWordStates} />
        <KpiCard label="Overdue Count" value={overdue} danger={overdue > 0} />
      </section>

      <section className="analytics-grid">
        <ChartPanel title="SRS Status Distribution">
          <PieChart data={slices} donut />
        </ChartPanel>
      </section>
    </PageShell>
  );
}
