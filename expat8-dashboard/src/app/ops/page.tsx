import Link from 'next/link';

import PageShell from '@/components/PageShell';
import { formatBytes, formatDateTime, summarizeLogArchives } from '@/lib/ops';
import { loadOpsOverview } from '@/lib/ops-data';

export const dynamic = 'force-dynamic';

export default async function OpsPage() {
  const overview = await loadOpsOverview();
  const summary = summarizeLogArchives(overview.archives);

  return (
    <PageShell
      title="Ops"
      actions={<Link href="/ops/logs" className="button">Browse archives</Link>}
    >
      <section className="ops-hero">
        <div>
          <p className="eyebrow">Operations workspace</p>
          <h2>Read-only visibility into backend health and uploaded support logs.</h2>
          <p className="muted">Checked {formatDateTime(overview.checkedAt)}</p>
        </div>
        <div className="ops-hero-note">
          <strong>No destructive controls.</strong>
          <span>Use the mobile log viewer to upload sanitized archives to the server.</span>
        </div>
      </section>

      <section className="stats-panel">
        <dl>
          <div>
            <dt>Live</dt>
            <dd>
              <span className="badge" data-status={overview.live.ok ? 'published' : 'failed'}>
                {overview.live.ok ? 'Healthy' : 'Unhealthy'}
              </span>
            </dd>
            <small className="muted">{overview.live.detail}</small>
          </div>
          <div>
            <dt>Ready</dt>
            <dd>
              <span className="badge" data-status={overview.ready.ok ? 'published' : 'failed'}>
                {overview.ready.ok ? 'Ready' : 'Blocked'}
              </span>
            </dd>
            <small className="muted">{overview.ready.detail}</small>
          </div>
          <div>
            <dt>Archives</dt>
            <dd>{overview.archives.length.toLocaleString()}</dd>
            <small className="muted">{formatBytes(summary.totalBytes)} stored</small>
          </div>
          <div>
            <dt>Retention</dt>
            <dd>{summary.activeCount} active</dd>
            <small className="muted">{summary.expiredCount} expired</small>
          </div>
        </dl>
      </section>

      <section className="table-panel">
        <div className="panel-heading">
          <div>
            <h3>Recent uploads</h3>
            <p className="muted">Latest sanitized bundles sent from mobile devices.</p>
          </div>
          <Link href="/ops/logs" className="button secondary">Open table</Link>
        </div>

        {overview.archivesError ? (
          <div className="empty-state error-state">{overview.archivesError}</div>
        ) : overview.archives.length === 0 ? (
          <div className="empty-state">
            No uploaded log archives yet. Users can send sanitized logs from the mobile log viewer.
          </div>
        ) : (
          <div className="ops-recent-list">
            {overview.archives.slice(0, 5).map((archive) => (
              <article key={archive.id} className="ops-recent-card">
                <div>
                  <strong>{archive.file_name}</strong>
                  <div className="muted">{formatDateTime(archive.uploaded_at)}</div>
                </div>
                <div className="ops-recent-meta">
                  <span>{formatBytes(archive.size_bytes)}</span>
                  <span className="badge" data-status={archive.retention_state === 'active' ? 'published' : 'failed'}>
                    {archive.retention_state}
                  </span>
                </div>
                <Link href={`/ops/logs/${archive.id}`} className="button secondary">View</Link>
              </article>
            ))}
          </div>
        )}
      </section>
    </PageShell>
  );
}
