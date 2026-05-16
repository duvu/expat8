'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV_LINKS = [
  { href: '/', label: 'Articles' },
  { href: '/articles/new', label: 'New Article' },
  { href: '/review', label: 'Vocabulary Review' },
  { href: '/speaking-prompts', label: 'Speaking Prompts' },
  { href: '/exam', label: 'Exam Results' },
  { href: '/users', label: 'Users' },
];

export default function SidebarNav() {
  const pathname = usePathname();

  return (
    <nav className="sidebar-nav">
      {NAV_LINKS.map(({ href, label }) => (
        <Link
          key={href}
          href={href}
          aria-current={
            href === '/'
              ? pathname === href ? 'page' : undefined
              : pathname.startsWith(href) ? 'page' : undefined
          }
        >
          {label}
        </Link>
      ))}
    </nav>
  );
}
