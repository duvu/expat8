import type { ReactNode } from 'react';

/** GET form that writes its fields to the query string. */
export default function FilterForm({ children }: { children: ReactNode }) {
  return (
    <form className="filter-form" method="get">
      {children}
      <button type="submit">Filter</button>
    </form>
  );
}
