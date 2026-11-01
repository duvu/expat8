import { formatAxisDate, formatCompact, formatNumber } from '@/lib/datetime';
import EmptyState from '../EmptyState';

/** Shared recharts props so every chart looks and reads the same. */
export const AXIS_TICK = { fontSize: 11 } as const;
export const GRID_PROPS = { strokeDasharray: '3 3', vertical: false } as const;
export const MARGIN = { top: 8, right: 16, left: 0, bottom: 0 } as const;

export const TOOLTIP_PROPS = {
  contentStyle: {
    background: 'var(--color-surface-solid)',
    border: '1px solid var(--color-line)',
    borderRadius: 10,
    boxShadow: 'var(--shadow-soft)',
    fontSize: 12,
    padding: '8px 12px',
  },
  labelStyle: { color: 'var(--color-ink)', fontWeight: 600, marginBottom: 4 },
  itemStyle: { color: 'var(--color-ink-muted)', padding: 0 },
  cursor: { fill: 'var(--color-accent-soft)', stroke: 'var(--color-line)' },
  labelFormatter: (label: unknown) => formatAxisDate(String(label)),
  formatter: (value: unknown) => (typeof value === 'number' || typeof value === 'string' ? formatNumber(value) : ''),
} as const;

export const LEGEND_PROPS = {
  verticalAlign: 'top',
  align: 'right',
  height: 32,
  iconType: 'circle',
  iconSize: 8,
  wrapperStyle: { fontSize: 12, paddingBottom: 8 },
} as const;

export const yTickFormatter = (value: number | string) => formatCompact(value);
export const xTickFormatter = (value: number | string) => formatAxisDate(String(value));

/** True when there is nothing to draw (no rows, or every plotted value is zero). */
export function isEmptyChart(data: Record<string, string | number>[], keys: string[]): boolean {
  return data.length === 0 || data.every((row) => keys.every((key) => !Number(row[key])));
}

export function ChartEmpty({ height }: { height: number }) {
  return (
    <div className="chart-empty" style={{ minHeight: height }}>
      <EmptyState icon="chart" title="No activity in this period" hint="Try a longer time range." />
    </div>
  );
}
