'use client';

import { Cell, Legend, Pie, PieChart as RechartsPieChart, ResponsiveContainer, Tooltip } from 'recharts';

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

export default function PieChart({ data, height = 220, donut = false }: Props) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <RechartsPieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          innerRadius={donut ? '55%' : 0}
          outerRadius="72%"
          paddingAngle={donut ? 2 : 0}
          dataKey="value"
        >
          {data.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color} />
          ))}
        </Pie>
        <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} formatter={(value) => (value != null ? Number(value).toLocaleString() : '0')} />
        <Legend iconSize={10} wrapperStyle={{ fontSize: 12 }} />
      </RechartsPieChart>
    </ResponsiveContainer>
  );
}
