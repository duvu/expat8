import PageShell from '@/components/PageShell';

export default function OpsLoading() {
  return (
    <PageShell title="Ops">
      <div className="empty-state">Loading backend health and archive summaries…</div>
    </PageShell>
  );
}
