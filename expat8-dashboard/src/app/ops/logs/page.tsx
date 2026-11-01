import Link from 'next/link';

import { filterLogArchives, formatBytes, summarizeLogArchives } from '@/lib/ops';
import { LOG_ARCHIVE_LIMIT_MAX, loadLogArchives } from '@/lib/ops-data';
import ActionForm from '@/components/ActionForm';
import DataTable from '@/components/DataTable';
import DateTime from '@/components/DateTime';
import EmptyState from '@/components/EmptyState';
import FilterForm from '@/components/FilterForm';
import PageShell from '@/components/PageShell';
import { RetentionBadge } from '@/components/StatusBadge';
import { deleteExpiredArchivesAction } from './actions';

export const metadata = { title: 'Log archives' };
export const dynamic = 'force-dynamic';

type Filters = { q?: string; source?: string; state?: string; from?: string; to?: string; user?: string; error?: string };

export default async function OpsLogsPage({ searchParams }: { searchParams: Promise<Filters> }) {
  const params = await searchParams;
  const { items, error } = await loadLogArchives();
  const archives = filterLogArchives(items, params);
  const stats = summarizeLogArchives(items);
  const sources = Array.from(new Set(items.map((archive) => archive.source_label ?? 'mobile'))).sort();

  return (
    <PageShell title="Log archives" description="Sanitized logs uploaded from mobile devices." breadcrumbs={[{ label: 'Ops and logs', href: '/ops' }, { label: 'Log archives' }]} actions={<Link href="/ops" className="button secondary">Ops home</Link>}>
      {params.error && <EmptyState tone="error" title={params.error} />}

      <section className="table-panel">
        <div className="ops-stats-bar">
          <span><strong>{items.length}</strong> total{items.length >= LOG_ARCHIVE_LIMIT_MAX ? ' (latest only)' : ''}</span>
          <span><strong>{formatBytes(stats.totalBytes)}</strong> stored</span>
          <span><strong>{stats.activeCount}</strong> active</span>
          <span><strong>{stats.expiredCount}</strong> expired</span>
          {stats.expiredCount > 0 && (
            <ActionForm
              action={deleteExpiredArchivesAction}
              label={`Delete all expired (${stats.expiredCount})`}
              buttonClassName="danger small"
              confirm={`Permanently delete ${stats.expiredCount} expired log archive(s)?`}
            />
          )}
        </div>
      </section>

      <section className="table-panel">
        <FilterForm>
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
              {sources.map((source) => <option key={source} value={source}>{source}</option>)}
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
        </FilterForm>
      </section>

      <section className="table-panel">
        {error ? (
          <EmptyState tone="error" title={error} />
        ) : (
          <DataTable
            rows={archives}
            rowKey={(archive) => archive.id}
            empty="No uploaded log archives matched the current filters."
            noun="archives"
            columns={[
              { label: 'File', render: (a) => <Link href={`/ops/logs/${a.id}`}>{a.file_name}</Link> },
              { label: 'Uploaded', nowrap: true, render: (a) => <DateTime value={a.uploaded_at} /> },
              { label: 'Size', numeric: true, nowrap: true, render: (a) => formatBytes(a.size_bytes) },
              { label: 'Source', render: (a) => a.source_label ?? 'mobile' },
              { label: 'Device', render: (a) => a.source_device_id ?? '—' },
              { label: 'Status', render: (a) => <RetentionBadge state={a.retention_state} /> },
            ]}
          />
        )}
      </section>
    </PageShell>
  );
}
