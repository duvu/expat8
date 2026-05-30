import Link from 'next/link';

import PageShell from '@/components/PageShell';
import { formatBytes, formatDateTime, summarizeLogArchives } from '@/lib/ops';
import { loadOpsOverview } from '@/lib/ops-data';

export const dynamic = 'force-dynamic';

const STALE_THRESHOLD_MS = 7 * 24 * 60 * 60 * 1000;

function isStale(isoDate: string | null): boolean {
  if (!isoDate) return true;
  return Date.now() - new Date(isoDate).getTime() > STALE_THRESHOLD_MS;
}

function pipelineStatus(pendingCount: number, failedCount: number): 'published' | 'failed' {
  return failedCount > 0 || pendingCount > 10 ? 'failed' : 'published';
}

function pipelineLabel(pendingCount: number, failedCount: number): string {
  if (failedCount > 0) return 'Failing';
  if (pendingCount > 10) return 'Backlogged';
  return 'Healthy';
}

export default async function OpsPage() {
  const overview = await loadOpsOverview();
  const summary = summarizeLogArchives(overview.archives);
  const lh = overview.loopHealth;
  const pipeline = overview.pipelineHealth;

  return (
    <PageShell
      title="Ops"
      actions={<Link href="/ops/logs" className="button">Browse archives</Link>}
    >
      <section className="ops-hero">
        <div>
          <p className="eyebrow">Operations workspace</p>
          <h2>Read-only visibility into backend health and uploaded support logs.</h2>
          <p className="muted">Checked {formatDateTime(overview.checkedAt)}</p>
        </div>
        <div className="ops-hero-note">
          <strong>No destructive controls.</strong>
          <span>Use the mobile log viewer to upload sanitized archives to the server.</span>
        </div>
      </section>

      <section className="stats-panel">
        <dl>
          <div>
            <dt>Live</dt>
            <dd>
              <span className="badge" data-status={overview.live.ok ? 'published' : 'failed'}>
                {overview.live.ok ? 'Healthy' : 'Unhealthy'}
              </span>
            </dd>
            <small className="muted">{overview.live.detail}</small>
          </div>
          <div>
            <dt>Ready</dt>
            <dd>
              <span className="badge" data-status={overview.ready.ok ? 'published' : 'failed'}>
                {overview.ready.ok ? 'Ready' : 'Blocked'}
              </span>
            </dd>
            <small className="muted">{overview.ready.detail}</small>
          </div>
          <div>
            <dt>Archives</dt>
            <dd>{overview.archives.length.toLocaleString()}</dd>
            <small className="muted">{formatBytes(summary.totalBytes)} stored</small>
          </div>
          <div>
            <dt>Retention</dt>
            <dd>{summary.activeCount} active</dd>
            <small className="muted">{summary.expiredCount} expired</small>
          </div>
        </dl>
      </section>

      <section className="table-panel">
        <div className="panel-heading">
          <div>
            <h3>Loop health (this week)</h3>
            <p className="muted">Aggregate speaking loop signals for the current week.</p>
          </div>
        </div>

        {overview.loopHealthError ? (
          <div className="empty-state error-state">{overview.loopHealthError}</div>
        ) : !lh ? (
          <div className="empty-state">Loop health data unavailable.</div>
        ) : (
          <dl className="stats-panel" style={{ marginTop: 0 }}>
            <div>
              <dt>Loop completions</dt>
              <dd>{lh.loop_completion_count.toLocaleString()}</dd>
              <small className="muted">Week of {lh.week_start}</small>
            </div>
            <div>
              <dt>Drill sessions</dt>
              <dd>{lh.drill_session_count.toLocaleString()}</dd>
              <small className="muted">speaking_drill_completed events</small>
            </div>
            <div>
              <dt>Latest approved prompt</dt>
              <dd>
                {lh.latest_approved_prompt_at ? (
                  <span className="badge" data-status={isStale(lh.latest_approved_prompt_at) ? 'failed' : 'published'}>
                    {isStale(lh.latest_approved_prompt_at) ? 'Stale' : 'Recent'}
                  </span>
                ) : (
                  <span className="badge" data-status="failed">None</span>
                )}
              </dd>
              <small className="muted">
                {lh.latest_approved_prompt_at ? formatDateTime(lh.latest_approved_prompt_at) : 'No approved prompts'}
              </small>
            </div>
            <div>
              <dt>Latest published passage</dt>
              <dd>
                {lh.latest_published_passage_at ? (
                  <span className="badge" data-status={isStale(lh.latest_published_passage_at) ? 'failed' : 'published'}>
                    {isStale(lh.latest_published_passage_at) ? 'Stale' : 'Recent'}
                  </span>
                ) : (
                  <span className="badge" data-status="failed">None</span>
                )}
              </dd>
              <small className="muted">
                {lh.latest_published_passage_at ? formatDateTime(lh.latest_published_passage_at) : 'No published passages'}
              </small>
            </div>
          </dl>
        )}
      </section>

      <section className="table-panel">
        <div className="panel-heading">
          <div>
            <h3>Content Pipeline</h3>
            <p className="muted">Article, memorization, and shadowing processing backlogs.</p>
          </div>
        </div>

        {overview.pipelineHealthError ? (
          <div className="empty-state error-state">{overview.pipelineHealthError}</div>
        ) : !pipeline ? (
          <div className="empty-state">Content pipeline data unavailable.</div>
        ) : (
          <dl className="stats-panel" style={{ marginTop: 0 }}>
            {[
              { label: 'Articles', section: pipeline.articles },
              { label: 'Memorization', section: pipeline.memorization },
              { label: 'Shadowing', section: pipeline.shadowing },
            ].map(({ label, section }) => {
              const status = pipelineStatus(section.pending_count, section.failed_count);
              return (
                <div key={label}>
                  <dt>{label}</dt>
                  <dd>
                    <span className="badge" data-status={status}>
                      {pipelineLabel(section.pending_count, section.failed_count)}
                    </span>
                  </dd>
                  <small className="muted">
                    {section.pending_count.toLocaleString()} pending · {section.failed_count.toLocaleString()} failed
                    {' · '}
                    {section.last_processed_at ? formatDateTime(section.last_processed_at) : 'No processed items'}
                  </small>
                </div>
              );
            })}
          </dl>
        )}
      </section>

      <section className="table-panel">
        <div className="panel-heading">
          <div>
            <h3>Recent uploads</h3>
            <p className="muted">Latest sanitized bundles sent from mobile devices.</p>
          </div>
          <Link href="/ops/logs" className="button secondary">Open table</Link>
        </div>

        {overview.archivesError ? (
          <div className="empty-state error-state">{overview.archivesError}</div>
        ) : overview.archives.length === 0 ? (
          <div className="empty-state">
            No uploaded log archives yet. Users can send sanitized logs from the mobile log viewer.
          </div>
        ) : (
          <div className="ops-recent-list">
            {overview.archives.slice(0, 5).map((archive) => (
              <article key={archive.id} className="ops-recent-card">
                <div>
                  <strong>{archive.file_name}</strong>
                  <div className="muted">{formatDateTime(archive.uploaded_at)}</div>
                </div>
                <div className="ops-recent-meta">
                  <span>{formatBytes(archive.size_bytes)}</span>
                  <span className="badge" data-status={archive.retention_state === 'active' ? 'published' : 'failed'}>
                    {archive.retention_state}
                  </span>
                </div>
                <Link href={`/ops/logs/${archive.id}`} className="button secondary">View</Link>
              </article>
            ))}
          </div>
        )}
      </section>
    </PageShell>
  );
}

