import PageShell from './PageShell';

/** Route-level loading placeholder: header, KPI row, and a panel, matching the real page rhythm. */
export default function PageSkeleton({ title, kpis = 4 }: { title: string; kpis?: number }) {
  return (
    <PageShell title={title}>
      <div className="skeleton-stack" role="status" aria-live="polite" aria-label={`Loading ${title}`}>
        <div className="kpi-grid" aria-hidden="true">
          {Array.from({ length: kpis }, (_, index) => <div key={index} className="skeleton skeleton-kpi" />)}
        </div>
        <div className="skeleton skeleton-panel" aria-hidden="true" />
        <span className="visually-hidden">Loading…</span>
      </div>
    </PageShell>
  );
}
