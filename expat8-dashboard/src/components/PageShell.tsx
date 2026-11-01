import type { ReactNode } from 'react';

import { getAdminConfig } from '@/lib/config';
import { formatClock, formatFullTimestamp } from '@/lib/datetime';
import Breadcrumbs, { type Crumb } from './Breadcrumbs';
import Icon from './Icon';
import ThemeToggle from './ThemeToggle';

interface PageShellProps {
  title: string;
  /** One line under the title. */
  description?: ReactNode;
  /** Overrides the automatic "Group / Page" trail (use on detail pages). */
  breadcrumbs?: Crumb[];
  /** Page-level buttons, shown on the right of the title. */
  actions?: ReactNode;
  children: ReactNode;
}

export default function PageShell({ title, description, breadcrumbs, actions, children }: PageShellProps) {
  const { envLabel } = getAdminConfig();
  const now = new Date();

  return (
    <>
      <header className="toolbar">
        <label htmlFor="sidebar-toggle" className="sidebar-toggle-btn" aria-label="Toggle navigation">
          <Icon name="menu" size={20} />
        </label>
        <Breadcrumbs crumbs={breadcrumbs} />
        <div className="toolbar-meta">
          <span className="env-chip" title="Environment">{envLabel}</span>
          <time className="toolbar-updated" dateTime={now.toISOString()} title={formatFullTimestamp(now)}>
            Updated {formatClock(now)} UTC
          </time>
          <ThemeToggle />
        </div>
      </header>
      <main id="main-content" className="page-content" tabIndex={-1}>
        <div className="page-inner">
          <div className="page-header">
            <div className="page-header-text">
              <h1 className="page-title">{title}</h1>
              {description && <p className="page-description">{description}</p>}
            </div>
            {actions && <div className="page-actions">{actions}</div>}
          </div>
          {children}
        </div>
      </main>
    </>
  );
}
