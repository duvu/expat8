'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { findActiveHref } from '@/lib/nav';
import { NAV_GROUPS } from '@/lib/nav-items';

export type Crumb = { label: string; href?: string };

const ALL_ITEMS = NAV_GROUPS.flatMap(({ group, items }) => items.map((item) => ({ ...item, group })));

function CrumbList({ crumbs }: { crumbs: Crumb[] }) {
  return (
    <nav className="breadcrumbs" aria-label="Breadcrumb">
      <ol>
        {crumbs.map((crumb, index) => (
          <li key={`${index}-${crumb.label}`}>
            {crumb.href ? <Link href={crumb.href}>{crumb.label}</Link> : <span aria-current={index === crumbs.length - 1 ? 'page' : undefined}>{crumb.label}</span>}
          </li>
        ))}
      </ol>
    </nav>
  );
}

/** Explicit crumbs when given, otherwise "Group / Page" derived from the sidebar definition. */
export default function Breadcrumbs({ crumbs }: { crumbs?: Crumb[] }) {
  const pathname = usePathname();
  if (crumbs) return <CrumbList crumbs={crumbs} />;

  const href = findActiveHref(pathname, ALL_ITEMS.map((item) => item.href));
  const item = ALL_ITEMS.find((candidate) => candidate.href === href);
  if (!item) return <CrumbList crumbs={[{ label: 'Expat8 Admin' }]} />;
  return <CrumbList crumbs={[{ label: item.group }, { label: item.label }]} />;
}
