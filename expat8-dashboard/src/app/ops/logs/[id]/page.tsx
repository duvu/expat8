import Link from 'next/link';
import { notFound } from 'next/navigation';

import PageShell from '@/components/PageShell';
import { formatBytes, formatDateTime, filterLogContentLines } from '@/lib/ops';
import { loadLogArchive, loadLogArchiveContent } from '@/lib/ops-data';

export const dynamic = 'force-dynamic';

export default async function OpsLogDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ q?: string; level?: string }>;
}) {
  const [{ id }, filters] = await Promise.all([params, searchParams]);
  const [{ archive, error: archiveError }, { content, error: contentError }] = await Promise.all([
    loadLogArchive(id),
    loadLogArchiveContent(id),
  ]);

  if (archiveError || contentError) {
    return (
      <PageShell title="Log Detail" actions={<Link href="/ops/logs" className="button secondary">Back</Link>}>
        <div className="empty-state error-state">{archiveError ?? contentError}</div>
      </PageShell>
    );
  }

  if (!archive) {
    notFound();
  }

  const lineResult = filterLogContentLines(content ?? '', filters);

  return (
    <PageShell title={archive.file_name} actions={<a href={archive.download_url} className="button">Download</a>}>
      <section className="ops-detail-grid">
        <dl className="ops-meta">
          <div><dt>Uploaded</dt><dd>{formatDateTime(archive.uploaded_at)}</dd></div>
          <div><dt>Size</dt><dd>{formatBytes(archive.size_bytes)}</dd></div>
          <div><dt>Source</dt><dd>{archive.source_label ?? 'mobile'}</dd></div>
          <div><dt>Device</dt><dd>{archive.source_device_id ?? '—'}</dd></div>
          <div><dt>User</dt><dd>{archive.source_user_id ?? '—'}</dd></div>
          <div><dt>Status</dt><dd>{archive.retention_state}</dd></div>
          <div><dt>Expires</dt><dd>{formatDateTime(archive.retention_expires_at)}</dd></div>
          <div><dt>Content type</dt><dd>{archive.content_type}</dd></div>
        </dl>
      </section>

      <section className="table-panel">
        <div className="panel-heading">
          <div>
            <h3>Archive content</h3>
            <p className="muted">{lineResult.matchedLines} of {lineResult.totalLines} lines shown.</p>
          </div>
          <div className="ops-detail-actions">
            <Link href={`/ops/logs/${archive.id}?level=error`} className="button secondary">Errors</Link>
            <Link href={`/ops/logs/${archive.id}?level=warning`} className="button secondary">Warnings</Link>
            <Link href={`/ops/logs/${archive.id}`} className="button secondary">All lines</Link>
          </div>
        </div>

        <form className="ops-filters" method="GET">
          <label>
            Search
            <input name="q" defaultValue={filters.q ?? ''} placeholder="Search log text" />
          </label>
          <label>
            Level
            <select name="level" defaultValue={filters.level ?? 'all'}>
              <option value="all">All</option>
              <option value="error">Error</option>
              <option value="warning">Warning</option>
              <option value="info">Info</option>
              <option value="debug">Debug</option>
            </select>
          </label>
          <button type="submit">Filter</button>
        </form>

        {lineResult.lines.length === 0 ? (
          <div className="empty-state">No log lines match the current filter.</div>
        ) : (
          <div className="ops-log-lines">
            {lineResult.lines.map((line) => (
              <pre key={line.lineNumber} className="ops-log-line">
                <span className="ops-line-number">{line.lineNumber}</span>
                <code>{line.text}</code>
              </pre>
            ))}
          </div>
        )}
      </section>
    </PageShell>
  );
}
