import { notFound } from 'next/navigation';

import { getUserDetail, getUserProficiency, getUserStudyStats } from '@/lib/db';
import PageShell from '@/components/PageShell';

export const dynamic = 'force-dynamic';

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const [detail, proficiency, studyStats] = await Promise.all([
    getUserDetail(id),
    getUserProficiency(id),
    getUserStudyStats(id),
  ]);

  if (!detail) {
    notFound();
  }

  return (
    <PageShell title="User Detail">
      {/* Profile header */}
      <section className="table-panel">
        <h2>Profile</h2>
        <dl className="article-meta">
          <div>
            <dt>Identifier</dt>
            <dd>{detail.identifier}</dd>
          </div>
          <div>
            <dt>Display Name</dt>
            <dd>{detail.display_name ?? <span className="muted">—</span>}</dd>
          </div>
          <div>
            <dt>Signed Up</dt>
            <dd>{new Date(detail.created_at).toLocaleString()}</dd>
          </div>
          <div>
            <dt>Sessions</dt>
            <dd>{detail.session_count.toLocaleString()}</dd>
          </div>
          <div>
            <dt>Cached Words</dt>
            <dd>{detail.cached_word_count.toLocaleString()}</dd>
          </div>
        </dl>
      </section>

      {/* Proficiency */}
      <section className="table-panel">
        <h2>Proficiency</h2>
        <table>
          <thead>
            <tr>
              <th>Language</th>
              <th>Level</th>
              <th>Last Updated</th>
            </tr>
          </thead>
          <tbody>
            {proficiency.length === 0 ? (
              <tr>
                <td colSpan={3}>
                  <div className="empty-state">No proficiency data.</div>
                </td>
              </tr>
            ) : (
              proficiency.map((p) => (
                <tr key={p.language}>
                  <td data-label="Language">{p.language}</td>
                  <td data-label="Level">{p.level}</td>
                  <td data-label="Last Updated">{new Date(p.updated_at).toLocaleDateString()}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      {/* Study event breakdown */}
      <section className="table-panel">
        <h2>Study Event Breakdown</h2>
        <table>
          <thead>
            <tr>
              <th>Rating</th>
              <th>Count</th>
            </tr>
          </thead>
          <tbody>
            {studyStats.breakdown.length === 0 ? (
              <tr>
                <td colSpan={2}>
                  <div className="empty-state">No study events.</div>
                </td>
              </tr>
            ) : (
              studyStats.breakdown.map((b) => (
                <tr key={b.rating}>
                  <td data-label="Rating">{b.rating}</td>
                  <td data-label="Count">{b.count.toLocaleString()}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      {/* Recent activity */}
      <section className="table-panel">
        <h2>Recent Activity (last 20 events)</h2>
        <table>
          <thead>
            <tr>
              <th>Word ID / Local ID</th>
              <th>Rating</th>
              <th>Occurred At</th>
            </tr>
          </thead>
          <tbody>
            {studyStats.recentEvents.length === 0 ? (
              <tr>
                <td colSpan={3}>
                  <div className="empty-state">No recent activity.</div>
                </td>
              </tr>
            ) : (
              studyStats.recentEvents.map((e) => (
                <tr key={e.id}>
                  <td data-label="Word ID / Local ID">
                    {e.word_id ?? e.local_word_id ?? <span className="muted">—</span>}
                  </td>
                  <td data-label="Rating">{e.rating}</td>
                  <td data-label="Occurred At">{e.occurred_at}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>
    </PageShell>
  );
}
