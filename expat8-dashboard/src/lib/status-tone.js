/**
 * Maps a raw status string to a semantic tone. Order matters: failure words win
 * over progress words ("processing_failed"), and "pending_processing" is waiting,
 * not in progress.
 */
export function statusTone(status) {
  const value = String(status ?? '').toLowerCase();
  if (/(fail|reject|dead|error|expired|overdue|blocked|unhealthy)/.test(value)) return 'danger';
  if (/(pending|draft|review_required|stale|backlog)/.test(value)) return 'warning';
  if (/(processing|running|learning|queued|in_progress)/.test(value)) return 'info';
  if (/(publish|approv|processed|complete|passed|pass$|active|master|ready|healthy|recent)/.test(value)) return 'success';
  return 'neutral';
}

/** "pending_processing" -> "Pending processing". */
export function humanizeStatus(status) {
  const text = String(status ?? '').replace(/[_-]+/g, ' ').trim();
  return text ? text.charAt(0).toUpperCase() + text.slice(1) : '—';
}
