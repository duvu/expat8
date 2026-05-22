import Link from 'next/link';

import PageShell from '@/components/PageShell';
import { listMemorizationPassages } from '@/lib/db';

export const dynamic = 'force-dynamic';

const STATUS_FILTERS = [
  ['pending_segmentation', 'Pending segmentation'],
  ['segmenting', 'Segmenting'],
  ['segmented', 'Segmented'],
  ['published', 'Published'],
  ['failed', 'Failed'],
] as const;

export default async function MemorizationPassagesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const params = await searchParams;
  const passages = await listMemorizationPassages({ status: params.status });

  return (
    <PageShell
      title="Memorization Passages"
      actions={<Link href="/memorization/passages/new" className="btn btn-primary">New Passage</Link>}
    >
      <form method="get" style={{ marginBottom: '1rem', display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
        <label>
          Status:{' '}
          <select name="status" defaultValue={params.status ?? ''}>
            <option value="">All</option>
            {STATUS_FILTERS.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </label>
        <button type="submit">Filter</button>
      </form>

      <section className="table-panel">
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Language</th>
              <th>Owner</th>
              <th>Visibility</th>
              <th>Status</th>
              <th>Segments</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {passages.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <div className="empty-state">No passages found.</div>
                </td>
              </tr>
            ) : (
              passages.map((passage) => (
                <tr key={passage.id}>
                  <td><Link href={`/memorization/passages/${passage.id}`}>{passage.title}</Link></td>
                  <td>{passage.language}</td>
                  <td>{passage.owner_type}</td>
                  <td><span className="badge" data-status={passage.visibility}>{passage.visibility}</span></td>
                  <td><span className="badge" data-status={passage.status}>{passage.status}</span></td>
                  <td>{passage.segment_count ?? 0}</td>
                  <td>{new Date(passage.created_at).toLocaleDateString()}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>
    </PageShell>
  );
}
