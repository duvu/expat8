import type { Key, ReactNode } from 'react';

export type Column<T> = {
  label: string;
  render: (row: T, index: number) => ReactNode;
};

type Props<T> = {
  rows: readonly T[];
  columns: Column<T>[];
  rowKey: (row: T, index: number) => Key;
  empty: ReactNode;
};

/** Server-rendered table; `data-label` drives the stacked mobile layout. */
export default function DataTable<T>({ rows, columns, rowKey, empty }: Props<T>) {
  return (
    <table>
      <thead>
        <tr>
          {columns.map((column) => <th key={column.label}>{column.label}</th>)}
        </tr>
      </thead>
      <tbody>
        {rows.length === 0 ? (
          <tr>
            <td colSpan={columns.length}><div className="empty-state">{empty}</div></td>
          </tr>
        ) : rows.map((row, index) => (
          <tr key={rowKey(row, index)}>
            {columns.map((column) => (
              <td key={column.label} data-label={column.label}>{column.render(row, index)}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
