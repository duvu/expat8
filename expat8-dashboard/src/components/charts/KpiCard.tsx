type Props = {
  label: string;
  value: string | number;
  sub?: string;
  accent?: boolean;
  danger?: boolean;
};

export default function KpiCard({ label, value, sub, accent, danger }: Props) {
  return (
    <div className="kpi-card" data-accent={accent ? '' : undefined} data-danger={danger ? '' : undefined}>
      <div className="kpi-label">{label}</div>
      <div className="kpi-value">{typeof value === 'number' ? value.toLocaleString() : value}</div>
      {sub && <div className="kpi-sub">{sub}</div>}
    </div>
  );
}
