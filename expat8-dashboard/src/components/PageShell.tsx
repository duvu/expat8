import type { ReactNode } from 'react';

interface PageShellProps {
  title: string;
  actions?: ReactNode;
  children: ReactNode;
}

export default function PageShell({ title, actions, children }: PageShellProps) {
  return (
    <>
      <header className="toolbar">
        <label htmlFor="sidebar-toggle" className="sidebar-toggle-btn" aria-label="Toggle navigation">&#9776;</label>
        <h1 className="toolbar-title">{title}</h1>
        {actions && <div className="toolbar-actions">{actions}</div>}
      </header>
      <main className="page-content">{children}</main>
    </>
  );
}
