'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { isSidebarLinkActive } from '@/lib/nav';

type NavItem = { href: string; label: string };
type NavGroup = { group: string; items: NavItem[] };

const NAV_GROUPS: NavGroup[] = [
  {
    group: 'Overview',
    items: [
      { href: '/', label: 'Dashboard' },
    ],
  },
  {
    group: 'Content',
    items: [
      { href: '/articles', label: 'Articles' },
      { href: '/articles/new', label: 'New Article' },
      { href: '/review', label: 'Vocabulary Review' },
      { href: '/speaking-prompts', label: 'Speaking Prompts' },
      { href: '/content/workplace-sentences', label: 'Workplace Sentences' },
    ],
  },
  {
    group: 'Memorization',
    items: [
      { href: '/memorization/passages', label: 'Passages' },
    ],
  },
  {
    group: 'Analytics',
    items: [
      { href: '/analytics/study-events', label: 'Study Events' },
      { href: '/analytics/exam', label: 'Exam Analytics' },
      { href: '/analytics/speaking', label: 'Speaking' },
      { href: '/analytics/content', label: 'Content Coverage' },
    ],
  },
  {
    group: 'System',
    items: [
      { href: '/users', label: 'Users' },
      { href: '/system/pipeline', label: 'Pipeline' },
      { href: '/system/srs', label: 'SRS Browser' },
      { href: '/ops', label: 'Ops' },
    ],
  },
];

export default function SidebarNav() {
  const pathname = usePathname();

  return (
    <nav className="sidebar-nav">
      {NAV_GROUPS.map(({ group, items }) => (
        <div key={group} className="sidebar-group">
          <div className="sidebar-group-label">{group}</div>
          {items.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              aria-current={isSidebarLinkActive(pathname, href) ? 'page' : undefined}
            >
              {label}
            </Link>
          ))}
        </div>
      ))}
    </nav>
  );
}
