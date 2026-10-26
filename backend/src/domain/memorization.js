// Memorization passage rules shared by both stores.

export function countWords(text) {
  return String(text ?? '').trim().split(/\s+/).filter(Boolean).length;
}

/** Splits a segment's text at a character index; null when either side would be empty. */
export function splitSegmentText(text, splitAt) {
  const index = Number(splitAt);
  if (!Number.isInteger(index) || index <= 0 || index >= text.length) {
    return null;
  }
  const leftText = text.slice(0, index).trim();
  const rightText = text.slice(index).trim();
  return leftText && rightText ? { leftText, rightText } : null;
}

export function mergeSegmentText(left, right) {
  return `${left.trim()} ${right.trim()}`.trim();
}

/** Per-status segment counts of a passage for one learner (missing progress counts as new). */
export function summarizePassageProgress(segments, progress) {
  if (segments.length === 0) {
    return { total: 0, mastered: 0, reviewing: 0, learning: 0, newCount: 0, percentage: 0 };
  }
  const progressBySegment = new Map(progress.map((p) => [p.segment_id, p]));
  let mastered = 0;
  let reviewing = 0;
  let learning = 0;
  let newCount = 0;
  for (const segment of segments) {
    const p = progressBySegment.get(segment.id);
    if (!p || p.status === 'new') newCount++;
    else if (p.status === 'mastered') mastered++;
    else if (p.status === 'review') reviewing++;
    else learning++;
  }
  const percentage = Math.round(((mastered + reviewing) / segments.length) * 100);
  return { total: segments.length, mastered, reviewing, learning, newCount, percentage };
}
