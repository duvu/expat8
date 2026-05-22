'use client';

import { Suspense } from 'react';
import TimeRangeSelector, { type TimeRange } from './TimeRangeSelector';

export default function TimeRangeSelectorWrapper({ current }: { current: TimeRange }) {
  return (
    <Suspense>
      <TimeRangeSelector current={current} />
    </Suspense>
  );
}
