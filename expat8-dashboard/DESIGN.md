# Expat8 dashboard design system

## 1. Atmosphere & identity

Expat8 should feel like a calm study room: focused, encouraging, and easy to scan during a short review session. The refreshed signature pairs a royal-indigo book mark with a mint spark. Product surfaces remain paper-like, with indigo as the action color and teal progress feedback. Density is reserved for operational data; learning progress gets breathing room and clear hierarchy.

## 2. Color

### Palette

| Role | Token | Light | Dark-ready value | Usage |
| --- | --- | --- | --- | --- |
| Canvas | `--color-canvas` | `#f4f6fb` | `#111827` | App background |
| Surface | `--color-surface` | `rgba(255,255,255,.88)` | `rgba(31,41,55,.92)` | Panels and shell |
| Surface solid | `--color-surface-solid` | `#ffffff` | `#1f2937` | Controls and elevated surfaces |
| Surface muted | `--color-surface-muted` | `#f8fafc` | `#243244` | Metadata, empty states, table rows |
| Ink | `--color-ink` | `#172033` | `#f8fafc` | Primary text |
| Ink muted | `--color-ink-muted` | `#64748b` | `#a8b4c5` | Secondary text |
| Ink subtle | `--color-ink-subtle` | `#94a3b8` | `#718096` | Disabled and tertiary text |
| Line | `--color-line` | `rgba(23,32,51,.10)` | `rgba(248,250,252,.14)` | Dividers and controls |
| Accent | `--color-accent` | `#352abf` | `#8f88ff` | Primary actions and current navigation |
| Accent strong | `--color-accent-strong` | `#241b97` | `#c2bcff` | Accent text and hover |
| Accent soft | `--color-accent-soft` | `rgba(53,42,191,.11)` | `rgba(143,136,255,.18)` | Selected and learning-focus surfaces |
| Mark mint | `brand.mint` | `#12cba9` | `#12cba9` | Spark in the logo; decorative accent only |
| Progress | `--color-progress` | `#0f8a72` | `#34d399` | Completed, healthy, mastered |
| Attention | `--color-attention` | `#b7791f` | `#f6c453` | Due soon, pending, caution |
| Danger | `--color-danger` | `#c2414b` | `#fb7185` | Failed, destructive, errors |
| Info | `--color-info` | `#2672a8` | `#60a5fa` | Neutral informational state |
| Log canvas | `--color-log-canvas` | `#172033` | `#0b1220` | Technical log output |
| Log ink | `--color-log-ink` | `#e2e8f0` | `#e2e8f0` | Technical log output |

Use semantic tokens in UI code. Raw colors are allowed only in this document and the token declaration. Royal indigo is the only action accent; progress and attention are semantic status colors. Mint belongs to the logo spark and must not be used for small text on light surfaces.

## 3. Typography

### Scale

| Level | Size | Weight | Line height | Usage |
| --- | --- | --- | --- | --- |
| Display | `clamp(1.75rem, 2vw, 2.4rem)` | 700 | 1.15 | Page titles |
| Heading | `clamp(1.4rem, 2vw, 2rem)` | 700 | 1.2 | Feature or ops headings |
| Section | `1.125rem` | 700 | 1.3 | Panel headings |
| Body | `1rem` | 400 | 1.5 | Default content |
| Body small | `.875rem` | 400 | 1.5 | Secondary content and controls |
| Caption | `.75rem` | 600 | 1.4 | Metadata and table labels |
| Overline | `.6875rem` | 700 | 1.3 | Group labels |
| Metric | `1.6rem` | 700 | 1 | KPI values |

Primary font: `ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`. Use tabular numerals for metrics, dates, IDs, and operational counts.

## 4. Spacing & layout

Base unit: 4px.

| Token | Value | Usage |
| --- | --- | --- |
| `--space-1` | `4px` | Icon-to-label and compact groups |
| `--space-2` | `8px` | Small gaps and field labels |
| `--space-3` | `12px` | Controls and toolbar groups |
| `--space-4` | `16px` | Standard panel internals |
| `--space-5` | `20px` | Content group separation |
| `--space-6` | `24px` | Panel padding and page gutters |
| `--space-7` | `28px` | Spacious panel padding |
| `--space-10` | `40px` | Major page rhythm |
| `--space-14` | `56px` | Bottom page breathing room |

The app shell uses a 240px sidebar, a 52px toolbar, and a fluid content column. The content column should remain readable rather than stretching indefinitely; dashboard grids collapse to one column below 900px and the navigation becomes an off-canvas panel below 768px.

## 5. Components

### App shell, toolbar, and sidebar
- **Structure**: semantic `aside`, sticky toolbar, scrollable `main`.
- **Variants**: desktop persistent sidebar; mobile off-canvas sidebar.
- **Spacing**: `--space-6` shell padding, `--space-3` navigation gaps.
- **States**: current route uses `--color-accent-soft`; hover uses the same tonal treatment; focus uses the global focus ring.
- **Accessibility**: landmark regions, keyboard reachable navigation, visible focus, mobile toggle label.
- **Brand**: use `/brand/expa8-mark.svg` beside the Expat8 wordmark; do not redraw the book and spark in a page component.

### Panel and table panel
- **Structure**: `section` or `.table-panel` with heading, content, and optional actions.
- **Variants**: default, muted, analytics, operational.
- **Spacing**: `--space-6` standard, `--space-7` for feature panels.
- **States**: default, loading skeleton, empty, error; avoid colored edge stripes.
- **Depth**: mixed strategy: subtle line plus tinted shadow and surface shift.

### Button and link action
- **Variants**: primary, secondary, text/tertiary, disabled.
- **Spacing**: `--space-3` × `--space-4`; `--radius-md`.
- **States**: hover, pressed, focus-visible, disabled.
- **Motion**: 120ms transform and color transition; pressed state uses a small translate, never layout animation.

### Field and form control
- **Variants**: input, select, textarea, inline form.
- **Spacing**: `--space-2` label gap, `--space-3` × `--space-4` control padding.
- **States**: default, focus-visible, invalid, disabled.
- **Accessibility**: visible labels, semantic controls, focus ring with at least 3:1 contrast.

### Status badge, KPI card, and chart panel
- **Variants**: neutral, progress, attention, danger, info.
- **Spacing**: `--space-2` to `--space-5`.
- **States**: default, empty, loading, error.
- **Rules**: status color is used in a tonal background plus text; never as a decorative stripe.

## 6. Motion & interaction

| Token | Value | Usage |
| --- | --- | --- |
| `--motion-fast` | `120ms` | Hover and press |
| `--motion-standard` | `200ms` | Navigation and panel transitions |
| `--motion-ease` | `ease-out` | Interactive feedback |

Only `transform`, `opacity`, and color/filter transitions are animated. Respect `prefers-reduced-motion` by reducing positional motion to a fade.

## 7. Depth & surface

Strategy: mixed. Panels use a quiet 1px line and a tinted shadow; nested metadata surfaces use a tonal shift with the muted surface token. Avoid generic black shadows and avoid accent-colored borders on rounded surfaces.

| Token | Value | Usage |
| --- | --- | --- |
| `--radius-sm` | `8px` | Compact controls |
| `--radius-md` | `12px` | Inputs, buttons, small cards |
| `--radius-lg` | `18px` | Cards and nested panels |
| `--radius-xl` | `24px` | Main panels |
| `--radius-full` | `9999px` | Status badges |
| `--shadow-panel` | `0 16px 40px rgba(23,32,51,.07)` | Main panels |
| `--shadow-soft` | `0 4px 16px rgba(23,32,51,.06)` | Small elevation |

## 8. Accessibility constraints & accepted debt

- Target WCAG 2.2 AA: 4.5:1 for body text, 3:1 for large text and UI boundaries.
- Every interactive element needs keyboard access, a visible `:focus-visible` state, and hover/pressed/disabled states where relevant.
- Do not communicate progress, error, or status by color alone; pair color with text, icon, or data.
- Preserve readable text at 200% zoom and support narrow screens without horizontal page overflow.
- Respect `prefers-reduced-motion`.

| Item | Location | Why accepted | Exit |
| --- | --- | --- | --- |
| Dark mode tokens are documented but not yet exposed as a user toggle | `globals.css` | Current product ships light mode only | Add when product requirements include theme switching |
