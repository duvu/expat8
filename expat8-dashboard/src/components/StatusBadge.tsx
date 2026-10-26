/**
 * Status pill. Colour comes from CSS substring matches on `data-status`
 * (pending / processing / published|approved / failed|rejected).
 */
export default function StatusBadge({ status, label }: { status: string | null | undefined; label?: string }) {
  const value = status ?? 'none';
  return <span className="badge" data-status={value}>{label ?? value}</span>;
}

/** Badge for a boolean health signal, reusing the success/failure palette. */
export function HealthBadge({ ok, okLabel, badLabel }: { ok: boolean; okLabel: string; badLabel: string }) {
  return <StatusBadge status={ok ? 'published' : 'failed'} label={ok ? okLabel : badLabel} />;
}

/** Log archive retention state (active / expired). */
export function RetentionBadge({ state }: { state: string }) {
  return <StatusBadge status={state === 'active' ? 'published' : 'failed'} label={state} />;
}
