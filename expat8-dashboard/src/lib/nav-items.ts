import type { IconName } from '@/components/Icon';

export type NavItem = { href: string; label: string; icon: IconName };
export type NavGroup = { group: string; items: NavItem[] };

/** Single source for the sidebar and the toolbar breadcrumb. */
export const NAV_GROUPS: NavGroup[] = [
  {
    group: 'Overview',
    items: [{ href: '/', label: 'Dashboard', icon: 'dashboard' }],
  },
  {
    group: 'Content',
    items: [
      { href: '/articles', label: 'Articles', icon: 'articles' },
      { href: '/articles/new', label: 'New article', icon: 'plus' },
      { href: '/speaking-prompts', label: 'Speaking prompts', icon: 'mic' },
      { href: '/content/workplace-sentences', label: 'Workplace sentences', icon: 'chat' },
    ],
  },
  {
    group: 'Memorization',
    items: [{ href: '/memorization/passages', label: 'Passages', icon: 'book' }],
  },
  {
    group: 'Analytics',
    items: [
      { href: '/analytics/study-events', label: 'Study events', icon: 'chart' },
      { href: '/analytics/exam', label: 'Exam analytics', icon: 'award' },
      { href: '/exam', label: 'Exam results', icon: 'list' },
      { href: '/analytics/speaking', label: 'Speaking', icon: 'activity' },
      { href: '/analytics/content', label: 'Content coverage', icon: 'layers' },
    ],
  },
  {
    group: 'System',
    items: [
      { href: '/users', label: 'Users', icon: 'users' },
      { href: '/system/pipeline', label: 'Pipeline', icon: 'pipeline' },
      { href: '/system/srs', label: 'SRS browser', icon: 'cards' },
      { href: '/ops', label: 'Ops and logs', icon: 'terminal' },
    ],
  },
];
