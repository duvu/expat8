export type TimeRange = '7d' | '30d' | '90d' | 'all';

export const TIME_RANGE_LABELS: Record<TimeRange, string> = {
  '7d': '7 days',
  '30d': '30 days',
  '90d': '90 days',
  'all': 'All time',
};

export function parseTimeRange(value: string | null | undefined): TimeRange {
  if (value === '7d' || value === '30d' || value === '90d' || value === 'all') return value;
  return '30d';
}

export function rangeToInterval(range: TimeRange): string {
  return range === '7d' ? '7 days' : range === '30d' ? '30 days' : range === '90d' ? '90 days' : '10 years';
}
