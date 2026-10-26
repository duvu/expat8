import type { ReactNode } from 'react';

import Sidebar from '@/components/Sidebar';
import './globals.css';

export const metadata = {
  title: 'Expat8 | Learn a little. Use it everywhere.',
  description: 'Expat8 learning content, vocabulary review, and progress operations.'
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
