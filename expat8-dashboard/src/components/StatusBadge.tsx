import { humanizeStatus, statusTone, type StatusTone } from '@/lib/status-tone';

/** Status pill: tonal colour + dot + text (never colour alone). */
export default function StatusBadge({
  status,
  label,
  tone,
}: {
  status: string | null | undefined;
  label?: string;
  /** Overrides the tone inferred from the status text. */
  tone?: StatusTone;
}) {
  const value = status ?? 'none';
  return (
    <span className="badge" data-tone={tone ?? statusTone(value)}>
      <span className="badge-dot" aria-hidden="true" />
      {label ?? humanizeStatus(value)}
    </span>
  );
}

/** Badge for a boolean health signal. */
export function HealthBadge({ ok, okLabel, badLabel }: { ok: boolean; okLabel: string; badLabel: string }) {
  return <StatusBadge status={ok ? okLabel : badLabel} tone={ok ? 'success' : 'danger'} />;
}

/** Log archive retention state (active / expired). */
export function RetentionBadge({ state }: { state: string }) {
  return <StatusBadge status={state} tone={state === 'active' ? 'success' : 'neutral'} />;
}
