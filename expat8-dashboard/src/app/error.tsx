'use client';

import PageShell from '@/components/PageShell';

/** Shown when a page render or server action throws (e.g. a backend call was rejected). */
export default function ErrorPage({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <PageShell title="Something went wrong">
      <div className="empty-state error-state">
        <p>{error.message || 'The request failed.'}</p>
        {error.digest && <p className="muted">Reference: {error.digest}</p>}
      </div>
      <div className="action-row">
        <button type="button" onClick={reset}>Try again</button>
      </div>
    </PageShell>
  );
}
