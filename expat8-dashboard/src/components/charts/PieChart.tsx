'use client';

import { Cell, Legend, Pie, PieChart as RechartsPieChart, ResponsiveContainer, Tooltip } from 'recharts';

import { ChartEmpty, LEGEND_PROPS, TOOLTIP_PROPS } from './chart-common';

type Slice = {
  name: string;
  value: number;
  color: string;
};

type Props = {
  data: Slice[];
  height?: number;
  donut?: boolean;
};

export default function PieChart({ data, height = 240, donut = false }: Props) {
  if (data.every((slice) => !slice.value)) return <ChartEmpty height={height} />;

  return (
    <ResponsiveContainer width="100%" height={height}>
      <RechartsPieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          innerRadius={donut ? '58%' : 0}
          outerRadius="80%"
          paddingAngle={donut ? 2 : 0}
          dataKey="value"
          stroke="var(--color-surface-solid)"
          strokeWidth={2}
          isAnimationActive={false}
        >
          {data.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color} />
          ))}
        </Pie>
        <Tooltip {...TOOLTIP_PROPS} labelFormatter={undefined} />
        <Legend {...LEGEND_PROPS} verticalAlign="bottom" align="center" />
      </RechartsPieChart>
    </ResponsiveContainer>
  );
}
