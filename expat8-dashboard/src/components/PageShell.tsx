import type { ReactNode } from 'react';

import Toolbar from './Toolbar';

interface PageShellProps {
  title: string;
  actions?: ReactNode;
  children: ReactNode;
}

export default function PageShell({ title, actions, children }: PageShellProps) {
  return (
    <>
      <Toolbar title={title} actions={actions} />
      <main className="page-content">{children}</main>
    </>
  );
}
