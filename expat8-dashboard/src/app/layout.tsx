import type { ReactNode } from 'react';

import Sidebar from '@/components/Sidebar';
import './globals.css';

export const metadata = {
  title: 'Expat8 Dashboard',
  description: 'Content ingestion, vocabulary review, and operations dashboard'
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <input type="checkbox" id="sidebar-toggle" className="sidebar-toggle-checkbox" />
        <div className="shell-grid">
          <Sidebar />
          {children}
        </div>
      </body>
    </html>
  );
}
