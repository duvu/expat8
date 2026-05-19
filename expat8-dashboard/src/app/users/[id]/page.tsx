import { notFound } from 'next/navigation';

import { getUserDetail, getUserProficiency, getUserStudyStats } from '@/lib/db';
import { getUserSpeakingStats, getUserExamHistory, getUserSrsStates } from '@/lib/analytics';
import PageShell from '@/components/PageShell';
import KpiCard from '@/components/charts/KpiCard';

export const dynamic = 'force-dynamic';

export default async function UserDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const { id } = await params;
  const { tab = 'study' } = await searchParams;

  const [detail, proficiency, studyStats, speakingStats, examHistory, srsStates] = await Promise.all([
    getUserDetail(id),
    getUserProficiency(id),
    getUserStudyStats(id),
    getUserSpeakingStats(id),
    getUserExamHistory(id),
    getUserSrsStates(id),
  ]);

  if (!detail) {
    notFound();
  }

  const tabs = [
    { key: 'study', label: 'Study Events' },
    { key: 'speaking', label: 'Speaking' },
    { key: 'srs', label: 'SRS States' },
    { key: 'exams', label: 'Exams' },
  ];

  return (
    <PageShell title={detail.display_name ?? detail.identifier}>
      {/* Profile header */}
      <section className="table-panel">
        <h2>Profile</h2>
        <dl className="article-meta">
          <div>
            <dt>Identifier</dt>
            <dd>{detail.identifier}</dd>
          </div>
          <div>
            <dt>Display Name</dt>
            <dd>{detail.display_name ?? <span className="muted">—</span>}</dd>
          </div>
          <div>
            <dt>Signed Up</dt>
            <dd>{new Date(detail.created_at).toLocaleString()}</dd>
          </div>
          <div>
            <dt>Sessions</dt>
            <dd>{detail.session_count.toLocaleString()}</dd>
          </div>
          <div>
            <dt>Cached Words</dt>
            <dd>{detail.cached_word_count.toLocaleString()}</dd>
          </div>
        </dl>
      </section>

      {/* Proficiency */}
      {proficiency.length > 0 && (
        <section className="table-panel">
          <h2>Proficiency</h2>
          <table>
            <thead>
              <tr>
                <th>Language</th>
                <th>Level</th>
                <th>Last Updated</th>
              </tr>
            </thead>
            <tbody>
              {proficiency.map((p) => (
                <tr key={p.language}>
                  <td data-label="Language">{p.language}</td>
                  <td data-label="Level">{p.level}</td>
                  <td data-label="Last Updated">{new Date(p.updated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      {/* Tab bar */}
      <nav className="tab-bar">
        {tabs.map(({ key, label }) => (
          <a
            key={key}
            href={`/users/${id}?tab=${key}`}
            className={tab === key ? 'active' : ''}
          >
            {label}
          </a>
        ))}
      </nav>

      {/* Study Events Tab */}
      {tab === 'study' && (
        <>
          <section className="kpi-grid">
            {studyStats.breakdown.map((b) => (
              <KpiCard key={b.rating} label={b.rating} value={b.count} />
            ))}
          </section>

          <section className="table-panel">
            <h2>Recent Activity (last 20)</h2>
            <table>
              <thead>
                <tr>
                  <th>Word ID / Local ID</th>
                  <th>Rating</th>
                  <th>Occurred At</th>
                </tr>
              </thead>
              <tbody>
                {studyStats.recentEvents.length === 0 ? (
                  <tr><td colSpan={3}><div className="empty-state">No recent activity.</div></td></tr>
                ) : studyStats.recentEvents.map((e) => (
                  <tr key={e.id}>
                    <td data-label="Word ID">{e.word_id ?? e.local_word_id ?? <span className="muted">—</span>}</td>
                    <td data-label="Rating">{e.rating}</td>
                    <td data-label="Occurred At">{e.occurred_at}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}

      {/* Speaking Tab */}
      {tab === 'speaking' && (
        <>
          <section className="kpi-grid">
            <KpiCard label="Total Speaking Events" value={speakingStats.totalEvents} />
            <KpiCard label="Drills Completed" value={speakingStats.drillsCompleted} />
            <KpiCard label="Last Speaking" value={speakingStats.lastSpeakingAt
              ? new Date(speakingStats.lastSpeakingAt).toLocaleDateString()
              : '—'} />
          </section>
          <section className="table-panel">
            <h2>Self-Rating Breakdown</h2>
            <table>
              <thead><tr><th>Rating</th><th>Count</th></tr></thead>
              <tbody>
                {speakingStats.selfRatingDistribution.length === 0 ? (
                  <tr><td colSpan={2}><div className="empty-state">No speaking events.</div></td></tr>
                ) : speakingStats.selfRatingDistribution.map((r) => (
                  <tr key={r.rating}>
                    <td data-label="Rating">{r.rating || '(none)'}</td>
                    <td data-label="Count">{r.count.toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}

      {/* SRS States Tab */}
      {tab === 'srs' && (
        <section className="table-panel">
          <h2>SRS Word States ({srsStates.length.toLocaleString()} words)</h2>
          <table>
            <thead>
              <tr>
                <th>Term</th>
                <th>Status</th>
                <th>Reviews</th>
                <th>Ease Factor</th>
                <th>Next Review</th>
              </tr>
            </thead>
            <tbody>
              {srsStates.length === 0 ? (
                <tr><td colSpan={5}><div className="empty-state">No SRS data.</div></td></tr>
              ) : srsStates.slice(0, 100).map((s) => (
                <tr key={s.word_id}>
                  <td data-label="Term">{s.term ?? s.word_id.slice(0, 12)}</td>
                  <td data-label="Status"><span className="badge" data-status={s.status}>{s.status}</span></td>
                  <td data-label="Reviews">{s.review_count}</td>
                  <td data-label="Ease">{s.ease_factor?.toFixed(2) ?? '—'}</td>
                  <td data-label="Next Review">
                    {s.next_review_at ? new Date(s.next_review_at).toLocaleDateString() : '—'}
                  </td>
                </tr>
              ))}
              {srsStates.length > 100 && (
                <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--muted)', padding: '8px' }}>Showing first 100 of {srsStates.length}</td></tr>
              )}
            </tbody>
          </table>
        </section>
      )}

      {/* Exams Tab */}
      {tab === 'exams' && (
        <section className="table-panel">
          <h2>Exam History</h2>
          <table>
            <thead>
              <tr>
                <th>Topic</th>
                <th>Language</th>
                <th>Score</th>
                <th>Result</th>
                <th>Date</th>
                <th>Certificate</th>
              </tr>
            </thead>
            <tbody>
              {examHistory.length === 0 ? (
                <tr><td colSpan={6}><div className="empty-state">No exam attempts.</div></td></tr>
              ) : examHistory.map((e) => (
                <tr key={e.id}>
                  <td data-label="Topic">{e.topic}</td>
                  <td data-label="Language">{e.language}</td>
                  <td data-label="Score">{e.score_pct.toFixed(1)}%</td>
                  <td data-label="Result">
                    <span className="badge" data-status={e.passed ? 'published' : 'processing_failed'}>
                      {e.passed ? 'Passed' : 'Failed'}
                    </span>
                  </td>
                  <td data-label="Date">{new Date(e.created_at).toLocaleDateString()}</td>
                  <td data-label="Certificate">
                    {e.certificate_id
                      ? <a href={`/v1/exam/certificate/${e.certificate_id}`} target="_blank" rel="noreferrer">View</a>
                      : <span className="muted">—</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </PageShell>
  );
}
