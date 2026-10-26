'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useTransition } from 'react';

import { type TimeRange, TIME_RANGE_LABELS } from '@/lib/time-range';

type Props = { current: TimeRange };

function TimeRangeButtons({ current }: Props) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [, startTransition] = useTransition();

  function select(range: TimeRange) {
    const next = new URLSearchParams(params.toString());
    next.set('range', range);
    startTransition(() => { router.push(`${pathname}?${next.toString()}`); });
  }

  return (
    <div className="time-range-selector">
      {(Object.keys(TIME_RANGE_LABELS) as TimeRange[]).map((r) => (
        <button
          key={r}
          type="button"
          className={current === r ? 'active' : ''}
          onClick={() => select(r)}
        >
          {TIME_RANGE_LABELS[r]}
        </button>
      ))}
    </div>
  );
}

/** useSearchParams needs a Suspense boundary; it lives here so pages don't repeat it. */
export default function TimeRangeSelector(props: Props) {
  return (
    <Suspense>
      <TimeRangeButtons {...props} />
    </Suspense>
  );
}
