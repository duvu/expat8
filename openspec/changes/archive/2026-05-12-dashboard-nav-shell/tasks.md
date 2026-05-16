## 1. CSS — Shell Grid & Sidebar/Toolbar Variables

- [x] 1.1 In `expat8-dashboard/src/app/globals.css`: add `--sidebar-width: 240px;` and `--toolbar-height: 52px;` CSS custom properties to `:root`
- [x] 1.2 Add `.shell-grid` rule: `display: grid; grid-template-columns: var(--sidebar-width) 1fr; grid-template-rows: var(--toolbar-height) 1fr; min-height: 100vh;`
- [x] 1.3 Add `.sidebar` rule: `grid-column: 1; grid-row: 1 / -1; position: sticky; top: 0; height: 100vh; overflow-y: auto; background: var(--surface); border-right: 1px solid var(--border); display: flex; flex-direction: column; padding: 24px 0;`
- [x] 1.4 Add `.toolbar` rule: `grid-column: 2; grid-row: 1; position: sticky; top: 0; z-index: 10; height: var(--toolbar-height); display: flex; align-items: center; justify-content: space-between; padding: 0 24px; background: var(--surface); border-bottom: 1px solid var(--border); backdrop-filter: blur(12px);`
- [x] 1.5 Add `.page-content` rule: `grid-column: 2; grid-row: 2; padding: 28px 24px 56px; display: flex; flex-direction: column; gap: 20px; overflow-y: auto;`
- [x] 1.6 Add sidebar nav link rules: `.sidebar-nav a` — `display: flex; align-items: center; gap: 10px; padding: 10px 20px; color: var(--muted); font-weight: 500; border-radius: 12px; margin: 2px 12px; transition: background 120ms ease, color 120ms ease;` and `.sidebar-nav a:hover, .sidebar-nav a[aria-current='page']` — `background: var(--accent-soft); color: var(--accent);`
- [x] 1.7 Add sidebar brand/logo area rule: `.sidebar-brand` — `padding: 0 20px 20px; font-size: 1.1rem; font-weight: 700; letter-spacing: -0.02em; color: var(--text);`
- [x] 1.8 Add responsive rules: `@media (max-width: 768px)` — `.shell-grid { grid-template-columns: 1fr; grid-template-rows: var(--toolbar-height) 1fr; }`, `.sidebar { position: fixed; top: 0; left: -100%; width: var(--sidebar-width); z-index: 20; transition: left 200ms ease; }`, `#sidebar-toggle:checked ~ .shell-grid .sidebar { left: 0; }`, `.sidebar-toggle-btn { display: flex; }` and on desktop `.sidebar-toggle-btn { display: none; }`
- [x] 1.9 Remove `.app-shell` padding rule (padding is now on `.page-content`) and remove `main { width: ...; margin: 0 auto; }` centering rule — content width is now controlled per-page

## 2. Components — Sidebar

- [x] 2.1 Create `expat8-dashboard/src/components/SidebarNav.tsx` as a `'use client'` component: import `Link` from `next/link` and `usePathname` from `next/navigation`; render `<nav className="sidebar-nav">` with links for: `{ href: '/', label: 'Articles' }`, `{ href: '/articles/new', label: 'New Article' }`, `{ href: '/review', label: 'Vocabulary Review' }`, `{ href: '/speaking-prompts', label: 'Speaking Prompts' }`, `{ href: '/exam', label: 'Exam Results' }`, `{ href: '/users', label: 'Users' }`; set `aria-current="page"` on the link whose `href` matches `pathname` (exact match for `/`, `startsWith` for all others)
- [x] 2.2 Create `expat8-dashboard/src/components/Sidebar.tsx` as a Server Component: render `<aside className="sidebar">` containing `<div className="sidebar-brand">Expat8</div>` and `<SidebarNav />`

## 3. Components — Toolbar & PageShell

- [x] 3.1 Create `expat8-dashboard/src/components/Toolbar.tsx` as a Server Component: accept `title: string` and `actions?: React.ReactNode` props; render `<header className="toolbar"><h1 className="toolbar-title">{title}</h1>{actions && <div className="toolbar-actions">{actions}</div>}</header>`; add `.toolbar-title` CSS rule in `globals.css`: `margin: 0; font-size: 1.1rem; font-weight: 700; letter-spacing: -0.02em;`
- [x] 3.2 Create `expat8-dashboard/src/components/PageShell.tsx` as a Server Component: accept `title: string`, `actions?: React.ReactNode`, `children: React.ReactNode`; render `<><Toolbar title={title} actions={actions} /><main className="page-content">{children}</main></>`

## 4. Root Layout — Wire Shell

- [x] 4.1 Update `expat8-dashboard/src/app/layout.tsx`: import `Sidebar` and wrap `children` in the shell grid: `<body><div className="shell-grid"><Sidebar />{children}</div></body>` — `children` will come from `PageShell` inside each page
- [x] 4.2 Remove `<div className="app-shell">` wrapper from `layout.tsx` (no longer needed)

## 5. Pages — Remove Per-Page Headers and Adopt PageShell

- [x] 5.1 Update `expat8-dashboard/src/app/page.tsx` (home/articles): import `PageShell`; remove the `<header className="page-header">` and its `<nav>` block; wrap content in `<PageShell title="Articles" actions={<Link href="/articles/new" className="button">New article</Link>}>…</PageShell>`
- [x] 5.2 Update `expat8-dashboard/src/app/review/page.tsx`: remove bare `<h1>` at top; wrap in `<PageShell title="Vocabulary Review">…</PageShell>`
- [x] 5.3 Update `expat8-dashboard/src/app/speaking-prompts/page.tsx`: remove bare `<h1>` and inline `<div className="filter-bar">` (keep the filter form but move it inside `PageShell`); wrap in `<PageShell title="Speaking Prompts">…</PageShell>`
- [x] 5.4 Update `expat8-dashboard/src/app/exam/page.tsx`: remove `<header className="page-header">` and `<nav>`; wrap in `<PageShell title="Exam Results">…</PageShell>`
- [x] 5.5 Update `expat8-dashboard/src/app/users/page.tsx`: remove `<header className="page-header">` and `<nav>`; wrap in `<PageShell title="Users">…</PageShell>`
- [x] 5.6 Update `expat8-dashboard/src/app/users/[id]/page.tsx`: remove per-page header if present; wrap in `<PageShell title="User Detail">…</PageShell>`
- [x] 5.7 Update `expat8-dashboard/src/app/articles/new/page.tsx`: remove bare `<h1>`; wrap in `<PageShell title="New Article">…</PageShell>`
- [x] 5.8 Update `expat8-dashboard/src/app/articles/[id]/page.tsx`: remove per-page header if present; wrap in `<PageShell title="Article">…</PageShell>`

## 6. Verification

- [x] 6.1 Run `cd expat8-dashboard && npm run build` — confirm zero TypeScript / build errors
- [ ] 6.2 Run `cd expat8-dashboard && npm run dev` — visually verify sidebar appears on all routes, active link is highlighted, toolbar title is correct on each page
- [ ] 6.3 Resize viewport to ≤ 768 px — confirm sidebar is hidden by default and toggled by the toolbar icon
- [ ] 6.4 Check that no page renders a duplicate `<header>` nav block alongside the shell sidebar
