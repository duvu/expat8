import type { Key, ReactNode } from 'react';

import EmptyState from './EmptyState';

export type Column<T> = {
  label: string;
  render: (row: T, index: number) => ReactNode;
  /** Right-aligned with tabular numerals (counts, scores, durations). */
  numeric?: boolean;
  /** Keeps the cell on one line (dates, ids). */
  nowrap?: boolean;
};

type Props<T> = {
  rows: readonly T[];
  columns: Column<T>[];
  rowKey: (row: T, index: number) => Key;
  /** Message shown when there are no rows (a string gets the standard empty state). */
  empty: ReactNode;
  /** Plural noun for the results summary, e.g. "articles" -> "Showing 50 articles". */
  noun?: string;
  /** Optional trailing totals row, aligned with `columns`. */
  footer?: ReactNode[];
};

function cellClass(column: { numeric?: boolean; nowrap?: boolean }) {
  return [column.numeric ? 'cell-numeric' : '', column.nowrap ? 'cell-nowrap' : ''].filter(Boolean).join(' ') || undefined;
}

/** Server-rendered table; `data-label` drives the stacked phone layout. */
export default function DataTable<T>({ rows, columns, rowKey, empty, noun, footer }: Props<T>) {
  return (
    <div className="table-block">
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              {columns.map((column) => <th key={column.label} className={cellClass(column)}>{column.label}</th>)}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr className="empty-row">
                <td colSpan={columns.length}>
                  {typeof empty === 'string' ? <EmptyState title={empty} hint="Adjust the filters or check back later." /> : empty}
                </td>
              </tr>
            ) : rows.map((row, index) => (
              <tr key={rowKey(row, index)}>
                {columns.map((column) => (
                  <td key={column.label} data-label={column.label} className={cellClass(column)}>{column.render(row, index)}</td>
                ))}
              </tr>
            ))}
          </tbody>
          {footer && rows.length > 0 && (
            <tfoot>
              <tr>
                {columns.map((column, index) => (
                  <td key={column.label} className={cellClass(column)}>{footer[index]}</td>
                ))}
              </tr>
            </tfoot>
          )}
        </table>
      </div>
      {noun && rows.length > 0 && (
        <p className="table-summary">Showing {rows.length.toLocaleString('en-US')} {noun}</p>
      )}
    </div>
  );
}
