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

import { AXIS_TICK, ChartEmpty, GRID_PROPS, LEGEND_PROPS, MARGIN, TOOLTIP_PROPS, isEmptyChart, xTickFormatter, yTickFormatter } from './chart-common';

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
  if (isEmptyChart(data, series.map((s) => s.key))) return <ChartEmpty height={height} />;

  const vertical = layout === 'vertical';
  return (
    <ResponsiveContainer width="100%" height={height}>
      <RechartsBarChart data={data} layout={layout} margin={MARGIN}>
        <CartesianGrid {...GRID_PROPS} vertical={vertical} horizontal={!vertical} />
        {vertical ? (
          <>
            <XAxis type="number" tick={AXIS_TICK} tickLine={false} axisLine={false} allowDecimals={false} tickFormatter={yTickFormatter} />
            <YAxis dataKey={xKey} type="category" tick={AXIS_TICK} tickLine={false} axisLine={false} width={120} />
          </>
        ) : (
          <>
            <XAxis dataKey={xKey} tick={AXIS_TICK} tickLine={false} axisLine={false} tickFormatter={xTickFormatter} minTickGap={16} tickMargin={8} />
            <YAxis tick={AXIS_TICK} tickLine={false} axisLine={false} width={44} allowDecimals={false} tickFormatter={yTickFormatter} />
          </>
        )}
        <Tooltip {...TOOLTIP_PROPS} />
        {series.length > 1 && <Legend {...LEGEND_PROPS} />}
        {series.map((s) => (
          <Bar
            key={s.key}
            dataKey={s.key}
            name={s.label}
            fill={s.color}
            stackId={stacked ? 'stack' : undefined}
            radius={stacked ? 0 : vertical ? [0, 4, 4, 0] : [4, 4, 0, 0]}
            maxBarSize={36}
            isAnimationActive={false}
          />
        ))}
      </RechartsBarChart>
    </ResponsiveContainer>
  );
}
