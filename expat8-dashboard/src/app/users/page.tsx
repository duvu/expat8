import Link from 'next/link';

import { listUsers, USERS_PAGE_SIZE } from '@/lib/db';
import { formatDate } from '@/lib/format';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';

export const dynamic = 'force-dynamic';

const dash = <span className="muted">—</span>;

function PageLink({ page, enabled, children }: { page: number; enabled: boolean; children: string }) {
  return enabled
    ? <Link href={`/users?page=${page}`} className="button secondary">{children}</Link>
    : <span className="button secondary disabled" aria-disabled="true">{children}</span>;
}

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ page?: string }> }) {
  const page = Math.max(1, Number((await searchParams).page ?? 1) || 1);
  const users = await listUsers({ page });

  return (
    <PageShell title="Users">
      <section className="table-panel">
        <DataTable
          rows={users}
          rowKey={(user) => user.id}
          empty="No users found."
          columns={[
            { label: 'Identifier', render: (u) => <Link href={`/users/${u.id}`}>{u.identifier}</Link> },
            { label: 'Display Name', render: (u) => u.display_name ?? dash },
            { label: 'Signed Up', render: (u) => formatDate(u.created_at) },
            { label: 'Last Activity', render: (u) => (u.last_activity ? formatDate(u.last_activity) : dash) },
            { label: 'Study Events', render: (u) => u.study_event_count.toLocaleString() },
          ]}
        />
      </section>

      <section className="table-panel">
        <div className="pagination">
          <PageLink page={page - 1} enabled={page > 1}>← Previous</PageLink>
          <span className="muted">Page {page}</span>
          <PageLink page={page + 1} enabled={users.length === USERS_PAGE_SIZE}>Next →</PageLink>
        </div>
      </section>
    </PageShell>
  );
}
