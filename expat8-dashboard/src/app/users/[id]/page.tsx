import Link from 'next/link';
import { notFound } from 'next/navigation';

import { getUserDetail, getUserProficiency, getUserStudyStats, listExamResults } from '@/lib/db';
import { getUserSpeakingStats, getUserSrsStates } from '@/lib/analytics';
import AccountActions from '@/components/AccountActions';
import DateTime from '@/components/DateTime';
import DataTable from '@/components/DataTable';
import LanguageChip from '@/components/LanguageChip';
import PageShell from '@/components/PageShell';
import { formatShortDate } from '@/lib/datetime';
import StatusBadge from '@/components/StatusBadge';
import KpiCard from '@/components/charts/KpiCard';
import KpiGrid from '@/components/charts/KpiGrid';

export const metadata = { title: 'User' };
export const dynamic = 'force-dynamic';

const TABS = [
  { key: 'study', label: 'Study Events' },
  { key: 'speaking', label: 'Speaking' },
  { key: 'srs', label: 'SRS States' },
  { key: 'exams', label: 'Exams' },
] as const;

const SRS_ROW_LIMIT = 100;
const dash = <span className="muted">—</span>;

export default async function UserDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const { id } = await params;
  const { tab = 'study' } = await searchParams;

  const [detail, proficiency] = await Promise.all([getUserDetail(id), getUserProficiency(id)]);
  if (!detail) {
    notFound();
  }

  return (
    <PageShell title={detail.display_name ?? detail.identifier} description={`Learner profile and activity. ID ${detail.identifier}`} breadcrumbs={[{ label: 'Users', href: '/users' }, { label: detail.display_name ?? detail.identifier }]}>
      <section className="table-panel">
        <h2>Profile</h2>
        <dl className="article-meta">
          <div><dt>Identifier</dt><dd>{detail.identifier}</dd></div>
          <div><dt>Display Name</dt><dd>{detail.display_name ?? dash}</dd></div>
          <div><dt>Signed Up</dt><dd><DateTime value={detail.created_at} /></dd></div>
          <div><dt>Sessions</dt><dd>{detail.session_count.toLocaleString()}</dd></div>
          <div><dt>Cached Words</dt><dd>{detail.cached_word_count.toLocaleString()}</dd></div>
        </dl>
      </section>

      <AccountActions userId={detail.id} identifier={detail.identifier} />

      {proficiency.length > 0 && (
        <section className="table-panel">
          <h2>Proficiency</h2>
          <DataTable
            rows={proficiency}
            rowKey={(p) => p.language}
            empty="No proficiency data."
            columns={[
              { label: 'Language', render: (p) => <LanguageChip code={p.language} /> },
              { label: 'Level', render: (p) => p.level },
              { label: 'Last updated', nowrap: true, render: (p) => <DateTime value={p.updated_at} dateOnly /> },
            ]}
          />
        </section>
      )}

      <nav className="tab-bar">
        {TABS.map(({ key, label }) => (
          <Link key={key} href={`/users/${id}?tab=${key}`} aria-current={tab === key ? 'page' : undefined}>
            {label}
          </Link>
        ))}
      </nav>

      {tab === 'study' && <StudyTab userId={id} />}
      {tab === 'speaking' && <SpeakingTab userId={id} />}
      {tab === 'srs' && <SrsTab userId={id} />}
      {tab === 'exams' && <ExamsTab userId={id} />}
    </PageShell>
  );
}

// Each tab loads only its own data.

async function StudyTab({ userId }: { userId: string }) {
  const { breakdown, recentEvents } = await getUserStudyStats(userId);
  return (
    <>
      <KpiGrid>
        {breakdown.map((b) => <KpiCard key={b.rating} label={b.rating} value={b.count} />)}
      </KpiGrid>
      <section className="table-panel">
        <h2>Recent activity (last 20)</h2>
        <DataTable
          rows={recentEvents}
          rowKey={(e) => e.id}
          empty="No recent activity."
          columns={[
            { label: 'Word ID / Local ID', render: (e) => e.word_id ?? e.local_word_id ?? dash },
            { label: 'Rating', render: (e) => e.rating },
            { label: 'Occurred', nowrap: true, render: (e) => <DateTime value={e.occurred_at} relative /> },
          ]}
        />
      </section>
    </>
  );
}

async function SpeakingTab({ userId }: { userId: string }) {
  const stats = await getUserSpeakingStats(userId);
  return (
    <>
      <KpiGrid>
        <KpiCard label="Speaking events" value={stats.totalEvents} />
        <KpiCard label="Drills completed" value={stats.drillsCompleted} />
        <KpiCard label="Last speaking" value={formatShortDate(stats.lastSpeakingAt)} />
      </KpiGrid>
      <section className="table-panel">
        <h2>Self-rating breakdown</h2>
        <DataTable
          rows={stats.selfRatingDistribution}
          rowKey={(r) => r.rating}
          empty="No speaking events."
          columns={[
            { label: 'Rating', render: (r) => r.rating || '(none)' },
            { label: 'Count', numeric: true, render: (r) => r.count.toLocaleString() },
          ]}
        />
      </section>
    </>
  );
}

async function SrsTab({ userId }: { userId: string }) {
  const states = await getUserSrsStates(userId);
  return (
    <section className="table-panel">
      <h2>SRS Word States ({states.length.toLocaleString()} words)</h2>
      <DataTable
        rows={states.slice(0, SRS_ROW_LIMIT)}
        rowKey={(s) => s.word_id}
        empty="No SRS data."
        columns={[
          { label: 'Term', render: (s) => s.term ?? s.word_id.slice(0, 12) },
          { label: 'Status', render: (s) => <StatusBadge status={s.status} /> },
          { label: 'Reviews', numeric: true, render: (s) => s.review_count },
          { label: 'Ease factor', numeric: true, render: (s) => (s.ease_factor != null ? Number(s.ease_factor).toFixed(2) : '—') },
          { label: 'Next review', nowrap: true, render: (s) => <DateTime value={s.next_review_at} dateOnly /> },
        ]}
      />
      {states.length > SRS_ROW_LIMIT && (
        <p className="muted table-footnote">Showing first {SRS_ROW_LIMIT} of {states.length}</p>
      )}
    </section>
  );
}

async function ExamsTab({ userId }: { userId: string }) {
  const exams = await listExamResults({ userId, limit: 500 });
  return (
    <section className="table-panel">
      <h2>Exam history</h2>
      <DataTable
        rows={exams}
        rowKey={(e) => e.id}
        empty="No exam attempts."
        columns={[
          { label: 'Topic', render: (e) => e.topic },
          { label: 'Language', render: (e) => <LanguageChip code={e.language} /> },
          { label: 'Score', numeric: true, render: (e) => `${Number(e.score_pct).toFixed(1)}%` },
          { label: 'Result', render: (e) => <StatusBadge status={e.passed ? 'published' : 'failed'} label={e.passed ? 'Passed' : 'Failed'} /> },
          { label: 'Date', nowrap: true, render: (e) => <DateTime value={e.created_at} dateOnly /> },
          {
            label: 'Certificate',
            render: (e) => e.certificate_id
              ? <a href={`/api/certificate/${e.certificate_id}`} target="_blank" rel="noreferrer">View</a>
              : dash,
          },
        ]}
      />
    </section>
  );
}
