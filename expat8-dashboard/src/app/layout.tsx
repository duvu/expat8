import type { ReactNode } from 'react';

import './globals.css';

export const metadata = {
  title: 'Expat8 Dashboard',
  description: 'Content ingestion and vocabulary review dashboard'
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="app-shell">{children}</div>
      </body>
    </html>
  );
}
