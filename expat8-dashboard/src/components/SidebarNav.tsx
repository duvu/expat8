'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { findActiveHref } from '@/lib/nav';
import { NAV_GROUPS } from '@/lib/nav-items';
import Icon from './Icon';

const ALL_HREFS = NAV_GROUPS.flatMap(({ items }) => items.map(({ href }) => href));

/** The mobile drawer is a CSS checkbox toggle; close it after navigating. */
function closeDrawer() {
  const toggle = document.getElementById('sidebar-toggle') as HTMLInputElement | null;
  if (toggle) toggle.checked = false;
}

export default function SidebarNav() {
  const pathname = usePathname();
  const activeHref = findActiveHref(pathname, ALL_HREFS);

  return (
    <nav className="sidebar-nav" aria-label="Primary">
      {NAV_GROUPS.map(({ group, items }) => (
        <div key={group} className="sidebar-group">
          <div className="sidebar-group-label">{group}</div>
          {items.map(({ href, label, icon }) => (
            <Link
              key={href}
              href={href}
              onClick={closeDrawer}
              aria-current={href === activeHref ? 'page' : undefined}
            >
              <Icon name={icon} />
              <span>{label}</span>
            </Link>
          ))}
        </div>
      ))}
    </nav>
  );
}
