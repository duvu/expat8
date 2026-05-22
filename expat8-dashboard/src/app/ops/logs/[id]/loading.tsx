import PageShell from '@/components/PageShell';

export default function OpsLogDetailLoading() {
  return (
    <PageShell title="Log Detail">
      <div className="empty-state">Loading log archive details…</div>
    </PageShell>
  );
}
