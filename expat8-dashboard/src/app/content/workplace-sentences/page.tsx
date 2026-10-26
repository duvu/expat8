import Link from 'next/link';

import { listWorkplaceSentences } from '@/lib/analytics';
import { formatDateTime, truncate } from '@/lib/format';
import { queryParam } from '@/lib/form';
import DataTable from '@/components/DataTable';
import FilterForm from '@/components/FilterForm';
import PageShell from '@/components/PageShell';

export const dynamic = 'force-dynamic';

export default async function WorkplaceSentencesPage({
  searchParams,
}: {
  searchParams: Promise<{ topic?: string; language?: string }>;
}) {
  const params = await searchParams;
  const topic = queryParam(params.topic);
  const language = queryParam(params.language);
  const sentences = await listWorkplaceSentences({ topic, language });

  return (
    <PageShell title="Workplace Sentences">
      <section className="table-panel">
        <FilterForm>
          <label>
            Topic
            <input type="text" name="topic" defaultValue={topic ?? ''} placeholder="e.g. meetings" />
          </label>
          <label>
            Language
            <input type="text" name="language" defaultValue={language ?? ''} placeholder="e.g. en" />
          </label>
        </FilterForm>
      </section>

      <section className="table-panel">
        <DataTable
          rows={sentences}
          rowKey={(s) => s.id}
          empty="No workplace sentences found."
          columns={[
            { label: 'Sentence', render: (s) => <span title={s.text}>{truncate(s.text, 80)}</span> },
            { label: 'Topic', render: (s) => s.topic ?? '—' },
            { label: 'Language', render: (s) => s.language },
            {
              label: 'Article',
              render: (s) => s.article_id
                ? <Link href={`/articles/${s.article_id}`}>{s.article_id}</Link>
                : <span className="muted">—</span>,
            },
            { label: 'Created At', render: (s) => formatDateTime(s.created_at) },
          ]}
        />
      </section>
    </PageShell>
  );
}
