import type { ReactNode } from 'react';

type Props = {
  title: string;
  /** Short caption under the title (unit, period). */
  description?: string;
  children: ReactNode;
};

export default function ChartPanel({ title, description, children }: Props) {
  return (
    <section className="chart-panel">
      <div className="chart-panel-header">
        <h2 className="chart-panel-title">{title}</h2>
        {description && <p className="chart-panel-description">{description}</p>}
      </div>
      {children}
    </section>
  );
}
