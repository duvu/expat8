import type { ReactNode } from 'react';

/** Responsive grid of KpiCards; `stacked` forces a single column (narrow side panels). */
export default function KpiGrid({ children, stacked }: { children: ReactNode; stacked?: boolean }) {
  return <div className={stacked ? 'kpi-grid single-column' : 'kpi-grid'}>{children}</div>;
}
