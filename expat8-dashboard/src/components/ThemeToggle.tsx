'use client';

import { useEffect, useState } from 'react';

import Icon, { type IconName } from './Icon';

import { THEME_STORAGE_KEY } from '@/lib/theme';
type Theme = 'system' | 'light' | 'dark';

const OPTIONS: { value: Theme; label: string; icon: IconName }[] = [
  { value: 'system', label: 'System theme', icon: 'monitor' },
  { value: 'light', label: 'Light theme', icon: 'sun' },
  { value: 'dark', label: 'Dark theme', icon: 'moon' },
];

function readStoredTheme(): Theme {
  try {
    const value = localStorage.getItem(THEME_STORAGE_KEY);
    return value === 'light' || value === 'dark' ? value : 'system';
  } catch {
    return 'system';
  }
}

/** Applies the choice to <html data-theme>; "system" removes it so the media query decides. */
function applyTheme(theme: Theme) {
  if (theme === 'system') delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = theme;
  try {
    if (theme === 'system') localStorage.removeItem(THEME_STORAGE_KEY);
    else localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch {
    // Storage can be blocked; the choice then lasts for this page view only.
  }
}

export default function ThemeToggle() {
  // The first paint is already themed by the inline script in layout.tsx; state only drives the buttons.
  const [theme, setTheme] = useState<Theme>('system');
  useEffect(() => setTheme(readStoredTheme()), []);

  function choose(next: Theme) {
    setTheme(next);
    applyTheme(next);
  }

  return (
    <div className="theme-toggle" role="group" aria-label="Color theme">
      {OPTIONS.map(({ value, label, icon }) => (
        <button
          key={value}
          type="button"
          aria-label={label}
          title={label}
          aria-pressed={theme === value}
          onClick={() => choose(value)}
        >
          <Icon name={icon} size={16} />
        </button>
      ))}
    </div>
  );
}
