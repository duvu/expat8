import Link from 'next/link';

import PageShell from '@/components/PageShell';
import { formatBytes, formatDateTime, filterLogArchives } from '@/lib/ops';
import { loadLogArchives } from '@/lib/ops-data';

export const dynamic = 'force-dynamic';

export default async function OpsLogsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; source?: string; state?: string; from?: string; to?: string }>;
}) {
  const params = await searchParams;
  const archivesResult = await loadLogArchives({ limit: 500 });
  const archives = filterLogArchives(archivesResult.items, params);
  const sources = Array.from(new Set(archivesResult.items.map((archive) => archive.source_label ?? 'mobile'))).sort();

  return (
    <PageShell title="Log Archives" actions={<Link href="/ops" className="button secondary">Ops home</Link>}>
      <section className="table-panel">
        <form className="ops-filters" method="GET">
          <label>
            Search
            <input name="q" defaultValue={params.q ?? ''} placeholder="File, device, app, retention" />
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
