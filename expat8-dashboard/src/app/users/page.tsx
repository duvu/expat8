import Link from 'next/link';

import { listUsers, USERS_PAGE_SIZE } from '@/lib/db';
import { findLookalikes } from '@/lib/lookalike-users';
import DateTime from '@/components/DateTime';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';

export const metadata = { title: 'Users' };
export const dynamic = 'force-dynamic';

const dash = <span className="muted">—</span>;

function PageLink({ page, enabled, children }: { page: number; enabled: boolean; children: string }) {
  return enabled
    ? <Link href={`/users?page=${page}`} className="button secondary">{children}</Link>
    : <span className="button secondary disabled" aria-disabled="true">{children}</span>;
}

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ page?: string; deleted?: string }> }) {
  const { page: rawPage, deleted } = await searchParams;
  const page = Math.max(1, Number(rawPage ?? 1) || 1);
  const users = await listUsers({ page });
  const lookalikes = findLookalikes(users);

  return (
    <PageShell title="Users" description="Registered learners and their activity.">
      {deleted && (
        <p className="notice success" role="status">
          Deleted the account <strong>{deleted}</strong> and its data.
        </p>
      )}
      <section className="table-panel">
        <DataTable
          rows={users}
          rowKey={(user) => user.id}
          empty="No users found."
          noun="users on this page"
          columns={[
            {
              label: 'Identifier',
              render: (u) => (
                <>
                  <Link href={`/users/${u.id}`}>{u.identifier}</Link>
                  {lookalikes.has(u.id) && (
                    <>
                      {' '}
                      <span className="badge" data-tone="warning" title={`Looks like ${lookalikes.get(u.id)!.join(', ')}`}>
                        <span className="badge-dot" aria-hidden="true" />
                        Possible duplicate of {lookalikes.get(u.id)!.join(', ')}
                      </span>
                    </>
                  )}
                </>
              ),
            },
            { label: 'Display name', render: (u) => u.display_name ?? dash },
            { label: 'Signed up', nowrap: true, render: (u) => <DateTime value={u.created_at} dateOnly /> },
            { label: 'Last activity', nowrap: true, render: (u) => <DateTime value={u.last_activity} relative /> },
            { label: 'Study events', numeric: true, render: (u) => u.study_event_count.toLocaleString() },
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
