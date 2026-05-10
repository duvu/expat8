import Link from 'next/link';

import { listExamResults } from '@/lib/db';

export const dynamic = 'force-dynamic';

export default async function ExamResultsPage({
  searchParams
}: {
  searchParams: Promise<{ user?: string; topic?: string; language?: string }>;
}) {
  const params = await searchParams;
  const userId = params.user ?? null;
  const topic = params.topic ?? null;
  const language = params.language ?? null;

  const results = await listExamResults({ userId, topic, language });

  return (
    <main>
      <header className="page-header">
        <h1>Exam Results</h1>
        <nav>
          <Link href="/">Home</Link>
        </nav>
      </header>

      <section className="table-panel">
        <form className="toolbar">
          <label>
            User ID
            <input name="user" defaultValue={userId ?? ''} placeholder="Filter by user ID" />
          </label>
          <label>
            Topic
            <input name="topic" defaultValue={topic ?? ''} placeholder="Filter by topic" />
          </label>
          <label>
            Language
            <input name="language" defaultValue={language ?? ''} placeholder="Filter by language" />
          </label>
          <button type="submit">Filter</button>
        </form>
      </section>

      <section className="table-panel">
        <table>
          <thead>
            <tr>
              <th>User</th>
              <th>Topic</th>
              <th>Language</th>
              <th>Difficulty</th>
              <th>Score</th>
              <th>Result</th>
              <th>Date</th>
              <th>Certificate</th>
            </tr>
          </thead>
          <tbody>
            {results.length === 0 ? (
              <tr>
                <td colSpan={8}>
                  <div className="empty-state">No exam attempts found for the current filter.</div>
                </td>
              </tr>
            ) : results.map((r) => (
              <tr key={r.id}>
                <td data-label="User">{r.user_id}</td>
                <td data-label="Topic">{r.topic}</td>
                <td data-label="Language">{r.language}</td>
                <td data-label="Difficulty">{r.difficulty_level ?? '—'}</td>
                <td data-label="Score">{r.correct_count}/{r.total_questions} ({Math.round(r.score_pct)}%)</td>
                <td data-label="Result">
                  <span className="badge" data-status={r.passed ? 'published' : 'processing_failed'}>
                    {r.passed ? 'Pass' : 'Fail'}
                  </span>
                </td>
                <td data-label="Date">{new Date(r.created_at).toLocaleString()}</td>
                <td data-label="Certificate">
                  {r.certificate_id
                    ? <Link href={`/exam/certificate/${r.certificate_id}`}>{r.certificate_id.slice(0, 8)}…</Link>
                    : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </main>
  );
}
