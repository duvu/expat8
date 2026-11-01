import Link from 'next/link';

import EmptyState from '@/components/EmptyState';
import PageShell from '@/components/PageShell';

export default function NotFound() {
  return (
    <PageShell title="Not found" description="That page or record does not exist.">
      <section className="table-panel">
        <EmptyState icon="search" title="Nothing here" hint="The link may be out of date, or the record was removed.">
          <div className="action-row empty-actions">
            <Link href="/" className="button primary">Back to dashboard</Link>
          </div>
        </EmptyState>
      </section>
    </PageShell>
  );
}
