import Link from 'next/link';

import { listAdminArticles } from '@/lib/db';
import { formatDateTime } from '@/lib/format';
import { queryParam } from '@/lib/form';
import { ARTICLE_STATUS_OPTIONS } from '@/lib/options';
import DataTable from '@/components/DataTable';
import FilterForm from '@/components/FilterForm';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';
import StatusBadge from '@/components/StatusBadge';

export const dynamic = 'force-dynamic';

export default async function ArticlesPage({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const status = queryParam((await searchParams).status);
  const articles = await listAdminArticles({ status });

  return (
    <PageShell title="Articles" actions={<Link href="/articles/new" className="button primary">New article</Link>}>
      <section className="table-panel">
        <FilterForm>
          <Select label="Status" name="status" options={ARTICLE_STATUS_OPTIONS} defaultValue={status ?? ''} emptyLabel="All" />
        </FilterForm>
      </section>

      <section className="table-panel">
        <DataTable
          rows={articles}
          rowKey={(article) => article.id}
          empty="No articles found for the current filter."
          columns={[
            { label: 'Title', render: (a) => <Link href={`/articles/${a.id}`}>{a.title}</Link> },
            { label: 'Language', render: (a) => a.language },
            { label: 'Status', render: (a) => <StatusBadge status={a.status} /> },
            { label: 'Visibility', render: (a) => <StatusBadge status={a.visibility} /> },
            { label: 'Updated', render: (a) => formatDateTime(a.updated_at) },
          ]}
        />
      </section>
    </PageShell>
  );
}
