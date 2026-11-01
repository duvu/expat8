import Icon, { type IconName } from '../Icon';

export type KpiTone = 'positive' | 'attention' | 'danger';

type Props = {
  label: string;
  value: string | number;
  /** Context line under the value ("of 12 users", "today"). Only pass what the data supports. */
  sub?: string;
  icon?: IconName;
  /** Semantic state; omit for the neutral default. */
  tone?: KpiTone;
};

export default function KpiCard({ label, value, sub, icon, tone }: Props) {
  return (
    <div className="kpi-card" data-tone={tone}>
      <div className="kpi-head">
        <span className="kpi-label">{label}</span>
        {icon && <span className="kpi-icon"><Icon name={icon} size={16} /></span>}
      </div>
      <div className="kpi-value">{typeof value === 'number' ? value.toLocaleString('en-US') : value}</div>
      {sub && <div className="kpi-sub">{sub}</div>}
    </div>
  );
}
