import Link from 'next/link';

import { listExamResults } from '@/lib/db';
import { formatDateTime } from '@/lib/format';
import { queryParam } from '@/lib/form';
import DataTable from '@/components/DataTable';
import FilterForm from '@/components/FilterForm';
import PageShell from '@/components/PageShell';
import StatusBadge from '@/components/StatusBadge';

export const dynamic = 'force-dynamic';

export default async function ExamResultsPage({
  searchParams,
}: {
  searchParams: Promise<{ user?: string; topic?: string; language?: string }>;
}) {
  const params = await searchParams;
  const userId = queryParam(params.user);
  const topic = queryParam(params.topic);
  const language = queryParam(params.language);
  const results = await listExamResults({ userId, topic, language });

  return (
    <PageShell title="Exam Results">
      <section className="table-panel">
        <FilterForm>
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
        </FilterForm>
      </section>

      <section className="table-panel">
        <DataTable
          rows={results}
          rowKey={(r) => r.id}
          empty="No exam attempts found for the current filter."
          columns={[
            { label: 'User', render: (r) => <Link href={`/users/${r.user_id}`}>{r.user_id}</Link> },
            { label: 'Topic', render: (r) => r.topic },
            { label: 'Language', render: (r) => r.language },
            { label: 'Difficulty', render: (r) => r.difficulty_level ?? '—' },
            { label: 'Score', render: (r) => `${r.correct_count}/${r.total_questions} (${Math.round(r.score_pct)}%)` },
            { label: 'Result', render: (r) => <StatusBadge status={r.passed ? 'published' : 'failed'} label={r.passed ? 'Pass' : 'Fail'} /> },
            { label: 'Date', render: (r) => formatDateTime(r.created_at) },
            {
              label: 'Certificate',
              render: (r) => r.certificate_id
                ? <a href={`/api/certificate/${r.certificate_id}`} target="_blank" rel="noreferrer">{r.certificate_id.slice(0, 8)}…</a>
                : '—',
            },
          ]}
        />
      </section>
    </PageShell>
  );
}
