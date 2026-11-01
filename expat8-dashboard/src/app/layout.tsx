import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';

import Sidebar from '@/components/Sidebar';
import { THEME_STORAGE_KEY } from '@/lib/theme';
import './globals.css';

export const metadata: Metadata = {
  title: { default: 'Expat8 Admin', template: '%s · Expat8 Admin' },
  description: 'Expat8 learning content, vocabulary review, and progress operations.',
  icons: { icon: '/brand/expa8-mark.svg', apple: '/brand/expa8-app-icon.png' },
};

export const viewport: Viewport = {
  colorScheme: 'light dark',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#f4f6fb' },
    { media: '(prefers-color-scheme: dark)', color: '#111827' },
  ],
};

/** Runs before first paint so a stored light/dark choice never flashes the wrong theme. */
const THEME_INIT_SCRIPT = `try{var t=localStorage.getItem('${THEME_STORAGE_KEY}');if(t==='light'||t==='dark')document.documentElement.dataset.theme=t}catch(e){}`;

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body>
        <a href="#main-content" className="skip-link">Skip to content</a>
        <input type="checkbox" id="sidebar-toggle" className="sidebar-toggle-checkbox" aria-label="Show navigation menu" />
        <div className="shell-grid">
          <Sidebar />
          <label htmlFor="sidebar-toggle" className="sidebar-backdrop" aria-hidden="true" />
          {children}
        </div>
      </body>
    </html>
  );
}
