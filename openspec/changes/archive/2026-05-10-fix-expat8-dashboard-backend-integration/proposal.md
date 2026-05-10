## Why

`expat8-dashboard` is deployed, but server-side rendering currently crashes because the container is missing the app credential envs needed by `backendFetch()`. The dashboard also needs to work reliably against the live `expat8-backend` service, including the existing admin speaking-prompts APIs and the current PostgreSQL-backed data model.

## What Changes

- Fix dashboard runtime configuration so SSR pages have the required backend app credential envs.
- Make the dashboard deploy cleanly beside `expat8-backend` and PostgreSQL in the worker compose stack.
- Keep dashboard data reads/writes aligned with the existing backend admin APIs for articles, vocabulary review, and speaking prompts.
- Harden the dashboard against missing or partial runtime configuration so a bad deploy fails clearly instead of crashing during page render.
- Validate the live backend/database contract used by the dashboard pages, especially the speaking-prompts review flow.

## Capabilities

### New Capabilities

- `dashboard-runtime-stability`: Dashboard pages can render with the required server-side runtime configuration and fail clearly when deployment envs are incomplete.
- `dashboard-backend-integration`: Dashboard pages continue to operate against the existing `expat8-backend` admin APIs in the worker deployment.

### Modified Capabilities

- `expat8-dashboard`: Runtime and deployment requirements change so the service can start and render reliably in the worker environment.
- `backend-container-deployment`: Worker deployment wiring changes if the dashboard service envs or compose wiring must be corrected.

## Impact

- `expat8-dashboard` Docker/runtime config, Next.js SSR pages, and server actions.
- Worker deployment compose/env wiring for dashboard backend credentials and database URL.
- Backend/admin API contract verification for existing article, vocabulary, and speaking-prompt routes.
- Documentation for the dashboard deployment environment if current operator guidance is incomplete.
