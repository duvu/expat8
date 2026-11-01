'use client';

import {
  Area,
  AreaChart,
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

import { AXIS_TICK, ChartEmpty, GRID_PROPS, LEGEND_PROPS, MARGIN, TOOLTIP_PROPS, isEmptyChart, xTickFormatter, yTickFormatter } from './chart-common';

export type SeriesConfig = {
  key: string;
  label: string;
  color: string;
  type?: 'area' | 'line';
};

type Props = {
  data: Record<string, string | number>[];
  xKey: string;
  series: SeriesConfig[];
  height?: number;
};

export default function TimeSeriesChart({ data, xKey, series, height = 260 }: Props) {
  if (isEmptyChart(data, series.map((s) => s.key))) return <ChartEmpty height={height} />;

  const hasArea = series.some((s) => s.type === 'area' || !s.type);
  const Chart = hasArea ? AreaChart : LineChart;

  return (
    <ResponsiveContainer width="100%" height={height}>
      <Chart data={data} margin={MARGIN}>
        <defs>
          {series.map((s) => (
            <linearGradient key={s.key} id={`grad-${s.key}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={s.color} stopOpacity={0.22} />
              <stop offset="95%" stopColor={s.color} stopOpacity={0} />
            </linearGradient>
          ))}
        </defs>
        <CartesianGrid {...GRID_PROPS} />
        <XAxis dataKey={xKey} tick={AXIS_TICK} tickLine={false} axisLine={false} tickFormatter={xTickFormatter} minTickGap={28} tickMargin={8} />
        <YAxis tick={AXIS_TICK} tickLine={false} axisLine={false} width={44} allowDecimals={false} tickFormatter={yTickFormatter} />
        <Tooltip {...TOOLTIP_PROPS} />
        <Legend {...LEGEND_PROPS} />
        {series.map((s) =>
          hasArea ? (
            <Area
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.label}
              stroke={s.color}
              fill={`url(#grad-${s.key})`}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4 }}
              isAnimationActive={false}
            />
          ) : (
            <Line
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.label}
              stroke={s.color}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4 }}
              isAnimationActive={false}
            />
          )
        )}
      </Chart>
    </ResponsiveContainer>
  );
}
