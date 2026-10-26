import Link from 'next/link';
import type { ReactNode } from 'react';

import { formatBytes, formatDateTime, summarizeLogArchives } from '@/lib/ops';
import { loadOpsOverview, type ContentPipelineSection } from '@/lib/ops-data';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';
import { HealthBadge, RetentionBadge } from '@/components/StatusBadge';

export const dynamic = 'force-dynamic';

const STALE_THRESHOLD_MS = 7 * 24 * 60 * 60 * 1000;
const PIPELINE_BACKLOG_THRESHOLD = 10;

function isRecent(isoDate: string | null): boolean {
  return isoDate != null && Date.now() - new Date(isoDate).getTime() <= STALE_THRESHOLD_MS;
}

function pipelineState({ pending_count, failed_count }: ContentPipelineSection) {
  if (failed_count > 0) return { ok: false, label: 'Failing' };
  if (pending_count > PIPELINE_BACKLOG_THRESHOLD) return { ok: false, label: 'Backlogged' };
  return { ok: true, label: 'Healthy' };
}

/** Panel that renders an error, an "unavailable" message, or its content. */
function OpsPanel({
  title,
  description,
  action,
  error,
  unavailable,
  children,
}: {
  title: string;
  description: string;
  action?: ReactNode;
  error: string | null;
  /** Shown instead of children when set (no data). */
  unavailable?: string | false;
  children: ReactNode;
}) {
  return (
    <section className="table-panel">
      <div className="panel-heading">
        <div>
          <h3>{title}</h3>
          <p className="muted">{description}</p>
        </div>
        {action}
      </div>
      {error ? (
        <div className="empty-state error-state">{error}</div>
      ) : unavailable ? (
        <div className="empty-state">{unavailable}</div>
      ) : children}
    </section>
  );
}

function Stat({ label, value, note }: { label: string; value: ReactNode; note: ReactNode }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
      <small className="muted">{note}</small>
    </div>
  );
}

function FreshnessStat({ label, at, none }: { label: string; at: string | null; none: string }) {
  return (
    <Stat
      label={label}
      value={at ? <HealthBadge ok={isRecent(at)} okLabel="Recent" badLabel="Stale" /> : <HealthBadge ok={false} okLabel="" badLabel="None" />}
      note={at ? formatDateTime(at) : none}
    />
  );
}

export default async function OpsPage() {
  const { checkedAt, live, ready, archives, loopHealth, pipelineHealth, games } = await loadOpsOverview();
  const summary = summarizeLogArchives(archives.items);
  const lh = loopHealth.data;
  const pipeline = pipelineHealth.data;
  const gamesData = games.data;

  return (
    <PageShell title="Ops" actions={<Link href="/ops/logs" className="button">Browse archives</Link>}>
      <section className="ops-hero">
        <div>
          <p className="eyebrow">Operations workspace</p>
          <h2>Visibility into backend health and uploaded support logs.</h2>
          <p className="muted">Checked {formatDateTime(checkedAt)}</p>
        </div>
        <div className="ops-hero-note">
          <strong>Read-only overview.</strong>
          <span>Use the mobile log viewer to upload sanitized archives to the server.</span>
        </div>
      </section>

      <section className="stats-panel">
        <dl>
          <Stat label="Live" value={<HealthBadge ok={live.ok} okLabel="Healthy" badLabel="Unhealthy" />} note={live.detail} />
          <Stat label="Ready" value={<HealthBadge ok={ready.ok} okLabel="Ready" badLabel="Blocked" />} note={ready.detail} />
          <Stat label="Archives" value={archives.items.length.toLocaleString()} note={`${formatBytes(summary.totalBytes)} stored`} />
          <Stat label="Retention" value={`${summary.activeCount} active`} note={`${summary.expiredCount} expired`} />
        </dl>
      </section>

      <OpsPanel
        title="Loop health (this week)"
        description="Aggregate speaking loop signals for the current week."
        error={loopHealth.error}
        unavailable={!lh && 'Loop health data unavailable.'}
      >
        {lh && (
          <dl className="stats-panel flush">
            <Stat label="Loop completions" value={lh.loop_completion_count.toLocaleString()} note={`Week of ${lh.week_start}`} />
            <Stat label="Drill sessions" value={lh.drill_session_count.toLocaleString()} note="speaking_drill_completed events" />
            <FreshnessStat label="Latest approved prompt" at={lh.latest_approved_prompt_at} none="No approved prompts" />
            <FreshnessStat label="Latest published passage" at={lh.latest_published_passage_at} none="No published passages" />
          </dl>
        )}
      </OpsPanel>

      <OpsPanel
        title="Games (last 30 days)"
        description="Word Blaster rounds and reviews recorded through games."
        error={games.error}
        unavailable={!gamesData && 'Game analytics unavailable.'}
      >
        {gamesData && (
          <>
            <dl className="stats-panel flush">
              <Stat label="Rounds" value={gamesData.total_rounds.toLocaleString()} note={`${gamesData.players.toLocaleString()} players`} />
              <Stat label="Mean accuracy" value={`${Math.round(gamesData.mean_accuracy * 100)}%`} note="Target 70–85%" />
              <Stat label="Words reviewed via games" value={gamesData.words_reviewed_via_games.toLocaleString()} note="Study events with a game source" />
              <Stat
                label="Accuracy distribution"
                value={
                  <span className="stat-compact">
                    {gamesData.accuracy_buckets.under_50} · {gamesData.accuracy_buckets.from_50_to_70} ·{' '}
                    {gamesData.accuracy_buckets.from_70_to_85} · {gamesData.accuracy_buckets.from_85}
                  </span>
                }
                note="<50% · 50–70% · 70–85% · ≥85%"
              />
            </dl>
            {gamesData.rounds_per_day.length > 0 && (
              <DataTable
                rows={gamesData.rounds_per_day.slice(-14)}
                rowKey={(row) => row.day}
                empty="No rounds."
                columns={[
                  { label: 'Day', render: (row) => row.day },
                  { label: 'Rounds', render: (row) => row.rounds },
                  { label: 'Players', render: (row) => row.players },
                ]}
              />
            )}
          </>
        )}
      </OpsPanel>

      <OpsPanel
        title="Content Pipeline"
        description="Article, memorization, and shadowing processing backlogs."
        error={pipelineHealth.error}
        unavailable={!pipeline && 'Content pipeline data unavailable.'}
      >
        {pipeline && (
          <dl className="stats-panel flush">
            {([
              ['Articles', pipeline.articles],
              ['Memorization', pipeline.memorization],
              ['Shadowing', pipeline.shadowing],
            ] as const).map(([label, section]) => {
              const state = pipelineState(section);
              return (
                <Stat
                  key={label}
                  label={label}
                  value={<HealthBadge ok={state.ok} okLabel={state.label} badLabel={state.label} />}
                  note={
                    `${section.pending_count.toLocaleString()} pending · ${section.failed_count.toLocaleString()} failed · ` +
                    (section.last_processed_at ? formatDateTime(section.last_processed_at) : 'No processed items')
                  }
                />
              );
            })}
          </dl>
        )}
      </OpsPanel>

      <OpsPanel
        title="Recent uploads"
        description="Latest sanitized bundles sent from mobile devices."
        action={<Link href="/ops/logs" className="button secondary">Open table</Link>}
        error={archives.error}
        unavailable={archives.items.length === 0 && 'No uploaded log archives yet. Users can send sanitized logs from the mobile log viewer.'}
      >
        <div className="ops-recent-list">
          {archives.items.slice(0, 5).map((archive) => (
            <article key={archive.id} className="ops-recent-card">
              <div>
                <strong>{archive.file_name}</strong>
                <div className="muted">{formatDateTime(archive.uploaded_at)}</div>
              </div>
              <div className="ops-recent-meta">
                <span>{formatBytes(archive.size_bytes)}</span>
                <RetentionBadge state={archive.retention_state} />
              </div>
              <Link href={`/ops/logs/${archive.id}`} className="button secondary">View</Link>
            </article>
          ))}
        </div>
      </OpsPanel>
    </PageShell>
  );
}
