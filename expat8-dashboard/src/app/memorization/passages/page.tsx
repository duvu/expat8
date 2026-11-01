import Link from 'next/link';

import { listMemorizationPassages } from '@/lib/db';
import { queryParam } from '@/lib/form';
import { PASSAGE_STATUS_OPTIONS } from '@/lib/options';
import DateTime from '@/components/DateTime';
import DataTable from '@/components/DataTable';
import FilterForm from '@/components/FilterForm';
import LanguageChip from '@/components/LanguageChip';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';
import StatusBadge from '@/components/StatusBadge';

export const metadata = { title: 'Passages' };
export const dynamic = 'force-dynamic';

export default async function MemorizationPassagesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const status = queryParam((await searchParams).status);
  const passages = await listMemorizationPassages({ status });

  return (
    <PageShell
      title="Memorization passages"
      description="Passages learners memorize, split into segments."
      actions={<Link href="/memorization/passages/new" className="button primary">New passage</Link>}
    >
      <section className="table-panel">
        <FilterForm>
          <Select label="Status" name="status" options={PASSAGE_STATUS_OPTIONS} defaultValue={status ?? ''} emptyLabel="All" />
        </FilterForm>
      </section>

      <section className="table-panel">
        <DataTable
          rows={passages}
          rowKey={(p) => p.id}
          empty="No passages found."
          noun="passages"
          columns={[
            { label: 'Title', render: (p) => <Link href={`/memorization/passages/${p.id}`}>{p.title}</Link> },
            { label: 'Language', render: (p) => <LanguageChip code={p.language} /> },
            { label: 'Owner', render: (p) => p.owner_type },
            { label: 'Visibility', render: (p) => <StatusBadge status={p.visibility} /> },
            { label: 'Status', render: (p) => <StatusBadge status={p.status} /> },
            { label: 'Segments', numeric: true, render: (p) => p.segment_count ?? 0 },
            { label: 'Created', nowrap: true, render: (p) => <DateTime value={p.created_at} dateOnly /> },
          ]}
        />
      </section>
    </PageShell>
  );
}
