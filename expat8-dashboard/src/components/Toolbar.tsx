import type { ReactNode } from 'react';

interface ToolbarProps {
  title: string;
  actions?: ReactNode;
}

export default function Toolbar({ title, actions }: ToolbarProps) {
  return (
    <header className="toolbar">
      <label htmlFor="sidebar-toggle" className="sidebar-toggle-btn">&#9776;</label>
      <h1 className="toolbar-title">{title}</h1>
      {actions && <div className="toolbar-actions">{actions}</div>}
    </header>
  );
}
