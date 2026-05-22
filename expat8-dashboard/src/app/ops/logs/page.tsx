import Link from 'next/link';

import PageShell from '@/components/PageShell';
import { formatBytes, formatDateTime, filterLogArchives, summarizeLogArchives } from '@/lib/ops';
import { loadLogArchives } from '@/lib/ops-data';
import { deleteExpiredArchivesAction } from './actions';

export const dynamic = 'force-dynamic';

export default async function OpsLogsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; source?: string; state?: string; from?: string; to?: string; user?: string }>;
}) {
  const params = await searchParams;
  const archivesResult = await loadLogArchives({ limit: 500 });
  const archives = filterLogArchives(archivesResult.items, params);
  const stats = summarizeLogArchives(archivesResult.items);
  const sources = Array.from(new Set(archivesResult.items.map((archive) => archive.source_label ?? 'mobile'))).sort();
  const expiredIds = archivesResult.items
    .filter((a) => a.retention_state === 'expired')
    .map((a) => a.id);

  async function handleDeleteExpired() {
    'use server';
    await deleteExpiredArchivesAction(expiredIds);
  }

  return (
    <PageShell title="Log Archives" actions={<Link href="/ops" className="button secondary">Ops home</Link>}>
      <section className="table-panel">
        <div className="ops-stats-bar">
          <span><strong>{stats.activeCount + stats.expiredCount}</strong> total</span>
          <span><strong>{formatBytes(stats.totalBytes)}</strong> stored</span>
          <span><strong>{stats.activeCount}</strong> active</span>
          <span><strong>{stats.expiredCount}</strong> expired</span>
          {expiredIds.length > 0 && (
            <form action={handleDeleteExpired} style={{ display: 'inline', marginLeft: 'auto' }}>
              <button type="submit" className="button danger small">
                Delete all expired ({expiredIds.length})
              </button>
            </form>
          )}
        </div>
      </section>

      <section className="table-panel">
        <form className="ops-filters" method="GET">
          <label>
            Search
            <input name="q" defaultValue={params.q ?? ''} placeholder="File, device, app, retention" />
          </label>
          <label>
            User
            <input name="user" defaultValue={params.user ?? ''} placeholder="User ID" />
          </label>
          <label>
            Source
            <select name="source" defaultValue={params.source ?? 'all'}>
              <option value="all">All</option>
              {sources.map((source) => (
                <option key={source} value={source}>{source}</option>
              ))}
            </select>
          </label>
          <label>
            State
            <select name="state" defaultValue={params.state ?? 'all'}>
              <option value="all">All</option>
              <option value="active">Active</option>
              <option value="expired">Expired</option>
            </select>
          </label>
          <label>
            From
            <input name="from" type="date" defaultValue={params.from ?? ''} />
          </label>
          <label>
            To
            <input name="to" type="date" defaultValue={params.to ?? ''} />
          </label>
          <button type="submit">Filter</button>
        </form>
      </section>

      <section className="table-panel">
        {archivesResult.error ? (
          <div className="empty-state error-state">{archivesResult.error}</div>
        ) : archives.length === 0 ? (
          <div className="empty-state">
            No uploaded log archives matched the current filters.
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>File</th>
                <th>Uploaded</th>
                <th>Size</th>
                <th>Source</th>
                <th>Device</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {archives.map((archive) => (
                <tr key={archive.id}>
                  <td data-label="File">
                    <Link href={`/ops/logs/${archive.id}`}>{archive.file_name}</Link>
                  </td>
                  <td data-label="Uploaded">{formatDateTime(archive.uploaded_at)}</td>
                  <td data-label="Size">{formatBytes(archive.size_bytes)}</td>
                  <td data-label="Source">{archive.source_label ?? 'mobile'}</td>
                  <td data-label="Device">{archive.source_device_id ?? '—'}</td>
                  <td data-label="Status">
                    <span className="badge" data-status={archive.retention_state === 'active' ? 'published' : 'failed'}>
                      {archive.retention_state}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </PageShell>
  );
}
