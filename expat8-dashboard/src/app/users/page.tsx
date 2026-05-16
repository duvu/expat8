import Link from 'next/link';

import { listUsers } from '@/lib/db';
import PageShell from '@/components/PageShell';

export const dynamic = 'force-dynamic';

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page ?? 1) || 1);
  const users = await listUsers({ page });

  return (
    <PageShell title="Users">
      <section className="table-panel">
        <table>
          <thead>
            <tr>
              <th>Identifier</th>
              <th>Display Name</th>
              <th>Signed Up</th>
              <th>Last Activity</th>
              <th>Study Events</th>
            </tr>
          </thead>
          <tbody>
            {users.length === 0 ? (
              <tr>
                <td colSpan={5}>
                  <div className="empty-state">No users found.</div>
                </td>
              </tr>
            ) : (
              users.map((user) => (
                <tr key={user.id}>
                  <td data-label="Identifier">
                    <Link href={`/users/${user.id}`}>{user.identifier}</Link>
                  </td>
                  <td data-label="Display Name">{user.display_name ?? <span className="muted">—</span>}</td>
                  <td data-label="Signed Up">{new Date(user.created_at).toLocaleDateString()}</td>
                  <td data-label="Last Activity">
                    {user.last_activity
                      ? new Date(user.last_activity).toLocaleDateString()
                      : <span className="muted">—</span>}
                  </td>
                  <td data-label="Study Events">{user.study_event_count.toLocaleString()}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      <section className="table-panel">
        <div className="pagination">
          {page > 1 ? (
            <Link href={`/users?page=${page - 1}`} className="button secondary">← Previous</Link>
          ) : (
            <span className="button secondary disabled" aria-disabled="true">← Previous</span>
          )}
          <span className="muted">Page {page}</span>
          {users.length === 50 ? (
            <Link href={`/users?page=${page + 1}`} className="button secondary">Next →</Link>
          ) : (
            <span className="button secondary disabled" aria-disabled="true">Next →</span>
          )}
        </div>
      </section>
    </PageShell>
  );
}
