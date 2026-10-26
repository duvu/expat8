import Link from 'next/link';

import { listMemorizationPassages } from '@/lib/db';
import { formatDate } from '@/lib/format';
import { queryParam } from '@/lib/form';
import { PASSAGE_STATUS_OPTIONS } from '@/lib/options';
import DataTable from '@/components/DataTable';
import FilterForm from '@/components/FilterForm';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';
import StatusBadge from '@/components/StatusBadge';

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
      title="Memorization Passages"
      actions={<Link href="/memorization/passages/new" className="button primary">New Passage</Link>}
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
          columns={[
            { label: 'Title', render: (p) => <Link href={`/memorization/passages/${p.id}`}>{p.title}</Link> },
            { label: 'Language', render: (p) => p.language },
            { label: 'Owner', render: (p) => p.owner_type },
            { label: 'Visibility', render: (p) => <StatusBadge status={p.visibility} /> },
            { label: 'Status', render: (p) => <StatusBadge status={p.status} /> },
            { label: 'Segments', render: (p) => p.segment_count ?? 0 },
            { label: 'Created', render: (p) => formatDate(p.created_at) },
          ]}
        />
      </section>
    </PageShell>
  );
}
