/** Inline 24px stroke icons (no icon library). Decorative by default. */
const PATHS = {
  dashboard: 'M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z',
  articles: 'M6 3h9l4 4v14H6V3zm9 0v4h4M9 12h7M9 16h7M9 8h3',
  plus: 'M12 5v14M5 12h14',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  mic: 'M12 3a3 3 0 00-3 3v6a3 3 0 006 0V6a3 3 0 00-3-3zM6 11a6 6 0 0012 0M12 17v4',
  chat: 'M4 5h16v11H9l-5 4V5z',
  book: 'M5 4h11a3 3 0 013 3v13H8a3 3 0 01-3-3V4zM5 17a3 3 0 013-3h11',
  chart: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
  award: 'M12 14a6 6 0 100-12 6 6 0 000 12zM8.5 13.5L7 22l5-3 5 3-1.5-8.5',
  list: 'M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01',
  layers: 'M12 3l9 5-9 5-9-5 9-5zM3 13l9 5 9-5M3 17.5l9 5 9-5',
  users: 'M16 20v-1.5a4 4 0 00-4-4H7a4 4 0 00-4 4V20M9.5 11a3.5 3.5 0 100-7 3.5 3.5 0 000 7zM21 20v-1.5a4 4 0 00-3-3.9M15.5 4.2a3.5 3.5 0 010 6.6',
  pipeline: 'M4 6h6v4H4V6zm10 0h6v4h-6V6zM7 10v4a2 2 0 002 2h6M17 10v4M4 18h6v2H4v-2zm10 0h6v2h-6v-2z',
  cards: 'M4 7h12v13H4V7zM8 7V4h12v13h-4',
  terminal: 'M4 5h16v14H4V5zM8 10l3 2-3 2M13 15h3',
  sun: 'M12 16a4 4 0 100-8 4 4 0 000 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  moon: 'M20 14.5A8 8 0 019.5 4 8 8 0 1020 14.5z',
  monitor: 'M3 4h18v12H3V4zM8 20h8M12 16v4',
  menu: 'M4 6h16M4 12h16M4 18h16',
  inbox: 'M3 13l3-8h12l3 8v6H3v-6zm0 0h5a4 4 0 008 0h5',
  alert: 'M12 3l10 18H2L12 3zM12 10v5M12 18h.01',
  search: 'M11 18a7 7 0 100-14 7 7 0 000 14zM21 21l-5-5',
  clock: 'M12 21a9 9 0 100-18 9 9 0 000 18zM12 7v5l3 2',
  activity: 'M3 12h4l3-8 4 16 3-8h4',
  server: 'M4 4h16v6H4V4zm0 10h16v6H4v-6zM8 7h.01M8 17h.01',
  chevron: 'M9 6l6 6-6 6',
} as const;

export type IconName = keyof typeof PATHS;

export default function Icon({ name, size = 18 }: { name: IconName; size?: number }) {
  return (
    <svg
      className="icon"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d={PATHS[name]} />
    </svg>
  );
}
