## Context

`expat8-dashboard` is a Next.js SSR app that renders admin pages by reading from PostgreSQL and mutating through backend admin APIs. In the worker deployment, the container currently starts but server rendering fails because `backendFetch()` cannot find `APP_CREDENTIAL_APP_ID` and `APP_CREDENTIAL_SECRET`.

The backend itself already exposes the dashboard-facing admin routes for articles, vocabulary review, and speaking prompts. The problem is not missing API surface; it is that the dashboard runtime environment and deployment wiring do not consistently provide the credentials and database settings the app expects.

## Goals / Non-Goals

**Goals:**
- Make the dashboard render reliably in the worker deployment.
- Ensure SSR pages have the app credentials they need for backend mutation calls.
- Keep dashboard reads aligned with the existing `expat8-backend` admin APIs and worker PostgreSQL schema.
- Fail clearly when runtime config is incomplete instead of throwing opaque SSR exceptions.
- Verify the live deployment path for the speaking-prompts page and the article/vocabulary admin pages.

**Non-Goals:**
- Redesign dashboard UI.
- Add new backend endpoints.
- Change the speaking data model or event schema.
- Move dashboard reads to direct DB access if backend APIs already exist.

## Decisions

### Decision 1: Treat dashboard credentials as required runtime config

The dashboard should not attempt to render mutation-capable pages if `APP_CREDENTIAL_APP_ID` or `APP_CREDENTIAL_SECRET` is missing. Those values are required by `backendFetch()` for server actions.

**Rationale:** The current failure is a runtime deployment problem, not a product feature gap. Making credentials mandatory surfaces misconfiguration immediately and avoids hidden partial behavior.

**Alternatives considered:**
- Silent fallback to unauthenticated calls. Rejected because admin mutations would fail later and more opaquely.
- Hard-code credentials in code. Rejected because it leaks secrets into the app bundle and breaks deployment hygiene.

### Decision 2: Keep dashboard reads on the current server-side DB access pattern

The dashboard already reads articles, vocabulary review items, and speaking prompts from PostgreSQL using server-side helpers. That pattern stays in place for now.

**Rationale:** The backend already exposes the necessary admin APIs for writes, but the existing dashboard structure depends on SSR reads for table rendering. Changing reads to API calls would be broader than needed for this fix.

**Alternatives considered:**
- Proxy every read through backend APIs. Rejected for this change because it would add churn without solving the immediate runtime issue.
- Direct DB reads from backend-only routes. Rejected because the current dashboard already has stable server-side DB helpers and the issue is deployment config, not architecture.

### Decision 3: Verify dashboard env wiring in the worker compose deployment

The worker deployment must pass `BACKEND_BASE_URL`, `EXPAT8_DASHBOARD_DATABASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, and `ADMIN_TOKEN` into `expat8-dashboard`.

**Rationale:** The current container shows blank app credential envs even though the service is running. Fixing compose/env wiring makes the deployment reproducible and prevents the same failure from returning.

**Alternatives considered:**
- Patch the running container manually. Rejected because it is not durable.
- Depend on the generic host `DATABASE_URL`. Rejected because the dashboard needs the expat8 database specifically, not the unrelated host default.

### Decision 4: Validate the dashboard against the live backend contract during rollout

The rollout should verify that the dashboard can load its pages and that the backend responds correctly for the admin speaking-prompts and article routes.

**Rationale:** The dashboard crash can mask backend/schema drift. A release that only fixes envs but leaves backend/schema mismatches unresolved would still fail in production use.

**Alternatives considered:**
- Assume the existing backend image is compatible. Rejected because worker logs already showed speaking-summary/schema mismatch symptoms.

## Risks / Trade-offs

- **[Risk]** The dashboard may still fail if the worker database does not match the backend image expectations. → **Mitigation:** verify the expat8 schema and required indexes before redeploying the dashboard.
- **[Risk]** More required envs increase deployment fragility. → **Mitigation:** document the required dashboard variables and keep them in compose/env files, not ad hoc shell state.
- **[Risk]** SSR pages remain coupled to PostgreSQL availability. → **Mitigation:** keep the failure explicit and observable; do not hide it behind partial fallback data.
- **[Risk]** Backend and dashboard deployments can drift independently. → **Mitigation:** add rollout verification that hits the dashboard pages and the relevant backend admin endpoints after deploy.
