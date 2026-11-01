/**
 * Chart series colors, taken from the shared brand tokens (BRAND.md). They are
 * CSS variables (declared per theme in app/globals.css as `--chart-*`) so every
 * series stays readable in both light and dark mode. Do not add other hues.
 */
export const CHART = {
  /** `--chart-primary`: the main series. */
  primary: 'var(--chart-primary)',
  /** `--chart-progress`: success, mastered, completed. */
  progress: 'var(--chart-progress)',
  /** `--chart-attention`: needs attention. */
  attention: 'var(--chart-attention)',
  /** `--chart-danger`: errors, rejected. */
  danger: 'var(--chart-danger)',
  /** `--chart-info`: a neutral second series. */
  info: 'var(--chart-info)',
} as const;
