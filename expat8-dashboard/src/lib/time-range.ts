export type TimeRange = '7d' | '30d' | '90d' | 'all';

export const TIME_RANGE_LABELS: Record<TimeRange, string> = {
  '7d': '7 days',
  '30d': '30 days',
  '90d': '90 days',
  'all': 'All time',
};

const TIME_RANGE_DAYS: Record<TimeRange, number> = { '7d': 7, '30d': 30, '90d': 90, 'all': 3650 };

export function parseTimeRange(value: string | null | undefined): TimeRange {
  return value != null && Object.hasOwn(TIME_RANGE_DAYS, value) ? (value as TimeRange) : '30d';
}

/** Parses `?range=` and returns both the selected range and its length in days. */
export function resolveTimeRange(value: string | null | undefined) {
  const range = parseTimeRange(value);
  return { range, days: TIME_RANGE_DAYS[range] };
}
