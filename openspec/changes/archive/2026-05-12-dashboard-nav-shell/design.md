## Context

The dashboard is a Next.js 14 App Router application. Each of the 8 existing pages owns its own `<header>` / `<nav>` block. `layout.tsx` is a minimal wrapper with no navigation chrome. There is no shared component directory under `src/`.

Current navigation pattern (duplicated across pages):
```tsx
<header className="page-header">
  <h1>Page title</h1>
  <nav><Link href="/">Home</Link> …</nav>
</header>
```
Some pages omit the nav entirely (e.g. `review/page.tsx`). Some use `page-header`, some use bare `h1`. This inconsistency is the core problem.

## Goals / Non-Goals

**Goals:**
- One fixed left sidebar listing every section, visible on every page, with an active-link indicator.
- One persistent top toolbar that shows the current page title and an optional right-side action slot (e.g. "New article" button on the home page).
- All page files stop owning navigation chrome; a `<PageShell>` component supplies the page title to the toolbar.
- The new layout is purely additive CSS — no new npm packages required.
- Responsive: on viewports ≤ 768 px the sidebar collapses and the toolbar shows a hamburger toggle.

**Non-Goals:**
- Dark mode (existing light-only design is kept as-is).
- Authentication UI in the sidebar — the dashboard is already admin-only at the network level.
- Animated sidebar transitions beyond a simple CSS `translate` toggle.
- Any backend or mobile changes.

## Decisions

### D1 — Layout engine: CSS Grid in `<body>`, not a wrapper `<div>`

The `RootLayout` body gets `display: grid; grid-template-columns: 240px 1fr; grid-template-rows: 48px 1fr; min-height: 100vh`. The sidebar spans both rows (`grid-row: 1 / -1`). The toolbar occupies `grid-column: 2; grid-row: 1`. Content occupies `grid-column: 2; grid-row: 2`.

**Alternative considered**: A single column layout where the toolbar spans full width and the sidebar is inside the content column. Rejected because it makes the sidebar harder to pin at full height without JavaScript.

### D2 — Active link: Client Component `<SidebarNav>`

The sidebar logo/branding section can be a pure Server Component. The navigation links require `usePathname()` to highlight the active route — so `<SidebarNav>` is marked `'use client'`. The rest of `<Sidebar>` stays a Server Component and imports `<SidebarNav>`.

**Alternative considered**: Passing `pathname` as a prop from the layout (which is a Server Component). Rejected because `headers()` / `cookies()` would be needed to read the current URL server-side, adding complexity.

### D3 — Page title supply: `<PageShell title>` prop, not React context

Each page wraps its content in `<PageShell title="Articles">`. `PageShell` renders a `<Toolbar title={title}>` at the top and `<div className="page-content">` below. This avoids context and keeps each page's intent visible at a glance.

**Alternative considered**: React context or `useContext` to lift the title. Rejected — adds a client-side context boundary for no benefit; the title can be known statically at page build time.

### D4 — Mobile sidebar: CSS-only with a hidden checkbox toggle

A `<input type="checkbox" id="sidebar-toggle">` + `<label htmlFor="sidebar-toggle">` in the toolbar provides the hamburger. The sidebar visibility is controlled by `#sidebar-toggle:checked ~ .sidebar`. No JavaScript required.

**Alternative considered**: `useState` in a Client Component. Rejected — adds JS hydration for a feature that works fine with CSS.

### D5 — Component location: `src/components/`

New files: `src/components/Sidebar.tsx`, `src/components/SidebarNav.tsx` (client), `src/components/Toolbar.tsx`, `src/components/PageShell.tsx`. No component library — plain TSX + CSS classes.

## Risks / Trade-offs

- **CSS Grid + `min-height: 100vh` on short pages**: pages shorter than the viewport height leave empty sidebar-adjacent space. Mitigation: `grid-template-rows: 48px 1fr` with `min-height: 100vh` on the grid parent handles this correctly.
- **`'use client'` on `<SidebarNav>` causes hydration for every page**: small (one `usePathname` call), acceptable.
- **Checkbox toggle accessibility**: `<label>` must have an accessible name and the checkbox must be visually hidden (not `display:none`). Mitigation: use `position: absolute; opacity: 0; pointer-events: none` on the checkbox.

## Migration Plan

1. Add `src/components/` with the four new components.
2. Update `globals.css` with grid/sidebar/toolbar rules; keep existing rules intact.
3. Update `layout.tsx` to mount `<Sidebar>` and `<Toolbar>` (toolbar title sourced later).
4. Wrap each page in `<PageShell title="…">` and remove the page-level `<header>` / `<nav>` block.
5. Test locally with `next dev`.

Rollback: revert `layout.tsx` and restore the per-page headers. No database or API state is affected.

## Open Questions

- None — all decisions made above.
