## Why

Every page in the dashboard renders its own `<header>` with navigation links, and the root `layout.tsx` provides no shared shell — the result is inconsistent heading styles, duplicated nav markup, and no stable visual anchor for the admin. A single shared shell with a fixed left sidebar and a persistent top toolbar gives every page a coherent identity and lets navigation evolve in one place.

## What Changes

- Add a permanent left sidebar component (`<Sidebar>`) listing all sections: Articles, New Article, Vocabulary Review, Speaking Prompts, Exam Results, Users.
- Add a persistent top toolbar component (`<Toolbar>`) that renders a page title slot and an optional right-side action slot.
- Refactor `layout.tsx` to mount both components inside a two-column CSS grid shell (`sidebar | content`).
- Remove the per-page `<header>` / `<nav>` blocks from every existing page and pass a page title via the toolbar slot.
- Extract a `<PageShell>` wrapper component that each page uses to supply its title and optional toolbar actions without owning layout chrome.
- Update `globals.css` to define the sidebar/toolbar CSS variables and grid layout; remove the now-unused `.app-shell` padding model.

## Capabilities

### New Capabilities

- `dashboard-nav-shell`: The shared layout shell that provides a fixed left sidebar and a persistent top toolbar used consistently across all dashboard pages.

### Modified Capabilities

- `expat8-dashboard`: Navigation model changes — each page no longer owns its header/nav; all navigation is centralised in the sidebar.

## Impact

- **`expat8-dashboard/src/app/layout.tsx`** — rewritten to include `<Sidebar>` and `<Toolbar>` in a grid shell.
- **`expat8-dashboard/src/app/globals.css`** — new grid/sidebar/toolbar CSS variables and rules.
- **All existing page files** (`page.tsx`, `review/page.tsx`, `users/page.tsx`, `exam/page.tsx`, `speaking-prompts/page.tsx`, `articles/new/page.tsx`, `articles/[id]/page.tsx`, `users/[id]/page.tsx`) — remove per-page `<header>` and `<nav>`, use `<PageShell>` instead.
- **New files**: `src/components/Sidebar.tsx`, `src/components/Toolbar.tsx`, `src/components/PageShell.tsx`.
- No backend API changes. No mobile changes. No database changes.
