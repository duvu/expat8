'use client';

import Link from 'next/link';

import EmptyState from '@/components/EmptyState';
import PageShell from '@/components/PageShell';

/** Shown when a page render or server action throws (e.g. a backend call was rejected). */
export default function ErrorPage({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <PageShell title="Something went wrong" description="The page could not be loaded. Nothing was changed.">
      <section className="table-panel">
        <EmptyState tone="error" title={error.message || 'The request failed.'} hint={error.digest ? `Reference: ${error.digest}` : 'Try again, or return to the dashboard.'}>
          <div className="action-row empty-actions">
            <button type="button" className="primary" onClick={reset}>Try again</button>
            <Link href="/" className="button secondary">Back to dashboard</Link>
          </div>
        </EmptyState>
      </section>
    </PageShell>
  );
}
