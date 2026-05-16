import Link from 'next/link';

import { getDashboardSummaryStats, listAdminArticles } from '@/lib/db';
import PageShell from '@/components/PageShell';

export const dynamic = 'force-dynamic';

export default async function HomePage({ searchParams }: { searchParams: Promise<{ status?: string }>; }) {
  const params = await searchParams;
  const status = params.status ?? null;
  const [articles, stats] = await Promise.all([
    listAdminArticles({ status }),
    getDashboardSummaryStats(),
  ]);

  return (
    <PageShell title="Articles" actions={<Link href="/articles/new" className="button">New article</Link>}>
      <section className="stats-panel">
        <dl>
          <div>
            <dt>Users</dt>
            <dd>{stats.total_users.toLocaleString()}</dd>
          </div>
          <div>
            <dt>Study Events</dt>
            <dd>{stats.total_study_events.toLocaleString()}</dd>
          </div>
          <div>
            <dt>Active (7d)</dt>
            <dd>{stats.active_last_7_days.toLocaleString()}</dd>
          </div>
          <div>
            <dt>Words</dt>
            <dd>{stats.total_words.toLocaleString()}</dd>
          </div>
        </dl>
      </section>

      <section className="table-panel">
        <form className="toolbar">
          <label>
            Status
            <select name="status" defaultValue={status ?? ''}>
              <option value="">All</option>
              <option value="pending_processing">Pending processing</option>
              <option value="processing">Processing</option>
              <option value="pending_review">Pending review</option>
              <option value="processed">Processed</option>
              <option value="published">Published</option>
              <option value="processing_failed">Failed</option>
            </select>
          </label>
          <button type="submit">Filter</button>
        </form>
      </section>

      <section className="table-panel">
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Language</th>
              <th>Status</th>
              <th>Visibility</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody>
            {articles.length === 0 ? (
              <tr>
                <td colSpan={5}>
                  <div className="empty-state">No articles found for the current filter.</div>
                </td>
              </tr>
            ) : articles.map((article) => (
              <tr key={article.id}>
                <td data-label="Title">
                  <Link href={`/articles/${article.id}`}>{article.title}</Link>
                </td>
                <td data-label="Language">{article.language}</td>
                <td data-label="Status"><span className="badge" data-status={article.status}>{article.status}</span></td>
                <td data-label="Visibility"><span className="badge" data-status={article.visibility}>{article.visibility}</span></td>
                <td data-label="Updated">{new Date(article.updated_at).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </PageShell>
  );
}
