/** Clamps a requested page size to 1..max. */
export function clampLimit(limit, max) {
  return Math.max(1, Math.min(limit, max));
}
