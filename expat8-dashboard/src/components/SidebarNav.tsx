'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { isSidebarLinkActive } from '@/lib/nav';

const NAV_LINKS = [
  { href: '/', label: 'Articles' },
  { href: '/articles/new', label: 'New Article' },
  { href: '/review', label: 'Vocabulary Review' },
  { href: '/speaking-prompts', label: 'Speaking Prompts' },
  { href: '/exam', label: 'Exam Results' },
  { href: '/users', label: 'Users' },
  { href: '/ops', label: 'Ops' },
];

export default function SidebarNav() {
  const pathname = usePathname();

  return (
    <nav className="sidebar-nav">
      {NAV_LINKS.map(({ href, label }) => (
        <Link
          key={href}
          href={href}
          aria-current={isSidebarLinkActive(pathname, href) ? 'page' : undefined}
        >
          {label}
        </Link>
      ))}
    </nav>
  );
}
