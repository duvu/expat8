'use client';

import {
  Bar,
  BarChart as RechartsBarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

type BarSeries = {
  key: string;
  label: string;
  color: string;
};

type Props = {
  data: Record<string, string | number>[];
  xKey: string;
  series: BarSeries[];
  height?: number;
  stacked?: boolean;
  layout?: 'horizontal' | 'vertical';
};

export default function BarChart({ data, xKey, series, height = 240, stacked = false, layout = 'horizontal' }: Props) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <RechartsBarChart data={data} layout={layout} margin={{ top: 4, right: 16, left: 0, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(15,23,42,0.06)" />
        {layout === 'horizontal' ? (
          <>
            <XAxis dataKey={xKey} tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
            <YAxis tick={{ fontSize: 11 }} tickLine={false} axisLine={false} width={40} />
          </>
        ) : (
          <>
            <XAxis type="number" tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
            <YAxis dataKey={xKey} type="category" tick={{ fontSize: 11 }} tickLine={false} axisLine={false} width={120} />
          </>
        )}
        <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} />
        <Legend iconSize={10} wrapperStyle={{ fontSize: 12 }} />
        {series.map((s) => (
          <Bar key={s.key} dataKey={s.key} name={s.label} fill={s.color} stackId={stacked ? 'stack' : undefined} radius={stacked ? 0 : [3, 3, 0, 0]} />
        ))}
      </RechartsBarChart>
    </ResponsiveContainer>
  );
}
