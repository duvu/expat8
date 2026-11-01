import { getSrsOverview } from '@/lib/analytics';
import ChartPanel from '@/components/ChartPanel';
import PageShell from '@/components/PageShell';
import KpiCard from '@/components/charts/KpiCard';
import KpiGrid from '@/components/charts/KpiGrid';
import PieChart from '@/components/charts/PieChart';
import { CHART } from '@/lib/chart-colors';

export const metadata = { title: 'SRS browser' };
export const dynamic = 'force-dynamic';

// Statuses written by the backend SRS scheduler (backend/src/domain/srs.js); `completed` is the
// pre-SRS name for words that left the review cycle and counts as mastered.
const STATUS_SLICES = [
  { statuses: ['learning'], name: 'Learning', color: CHART.info },
  { statuses: ['review'], name: 'Review', color: CHART.primary },
  { statuses: ['mastered', 'completed'], name: 'Mastered', color: CHART.progress },
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
    <PageShell title="SRS browser" description="Spaced-repetition state of every learner word.">
      <KpiGrid>
        <KpiCard label="Tracked words" value={totalWordStates} sub="learner word states" icon="cards" />
        <KpiCard label="Overdue reviews" value={overdue} sub={overdue > 0 ? 'past their review date' : 'nothing overdue'} icon="clock" tone={overdue > 0 ? 'attention' : 'positive'} />
      </KpiGrid>

      <section className="analytics-grid">
        <ChartPanel title="Status distribution" description="Words by learning stage">
          <PieChart data={slices} donut />
        </ChartPanel>
      </section>
    </PageShell>
  );
}
