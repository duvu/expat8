# Dashboard Guide

The admin dashboard lives in `expat8-dashboard/`. It is a Next.js 15 app using React 19, TypeScript, and Node.js 22-era dependencies.

## Commands

```bash
cd expat8-dashboard
npm install
npm run dev
npm run build
npm run lint
npm test
```

The root Compose stack also builds and starts the dashboard as `expat8-dashboard` on `http://localhost:${DASHBOARD_PORT:-3000}`.

## Environment

The Compose service defines these dashboard variables:

| Variable | Purpose |
|---|---|
| `BACKEND_BASE_URL` | Backend URL used by dashboard server/runtime; Compose defaults to `http://backend:8787`. |
| `EXPAT8_DASHBOARD_DATABASE_URL` | PostgreSQL connection string for dashboard-side DB access. |
| `ADMIN_TOKEN` | Admin token for backend admin endpoints. |
| `APP_CREDENTIAL_APP_ID` | App credential id for signed backend calls. |
| `APP_CREDENTIAL_SECRET` | App credential secret for signed backend calls. |

Root Compose maps host env names into the service:

- `DASHBOARD_BACKEND_BASE_URL` → `BACKEND_BASE_URL`.
- `DASHBOARD_APP_CREDENTIAL_APP_ID` → `APP_CREDENTIAL_APP_ID`.
- `DASHBOARD_APP_CREDENTIAL_SECRET` → `APP_CREDENTIAL_SECRET`.
- `DASHBOARD_PORT` controls the host port, default `3000`.

## Admin Authentication Model

Backend admin endpoints require both:

1. Standard app credential signing for `/v1/*`.
2. An admin token accepted by backend `ADMIN_API_TOKENS`.

Keep dashboard/admin secrets outside source control. Use placeholders in docs and committed examples.

## Admin Workflows

The dashboard is the admin surface for:

- Article upload/management.
- Article processing status review.
- Vocabulary review and publishing decisions.
- Speaking prompt review/admin workflows.

Backend article visibility currently accepts `private` and `published`; `shared` is rejected for admin article patching.

## Local Development Flow

1. Start backend/PostgreSQL with Compose, or run backend separately.
2. Export dashboard env values for the backend URL, app credentials, database URL, and admin token.
3. Run `npm run dev` in `expat8-dashboard/`.
4. Exercise dashboard workflows against a backend with matching app credential and admin-token configuration.

## Build Notes

- Run `npm run build` before shipping dashboard changes.
- Run `npm run lint` when the Next lint setup is available and compatible with the installed Next.js version.
- Use `npm test` for dashboard Node test coverage.
