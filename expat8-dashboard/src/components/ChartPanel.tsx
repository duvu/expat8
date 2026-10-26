import type { ReactNode } from 'react';

export default function ChartPanel({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="chart-panel">
      <div className="chart-panel-header">
        <h2 className="chart-panel-title">{title}</h2>
      </div>
      {children}
    </div>
  );
}
