import PageShell from '@/components/PageShell';

export default function OpsLogsLoading() {
  return (
    <PageShell title="Log Archives">
      <div className="empty-state">Loading uploaded log archives…</div>
    </PageShell>
  );
}
