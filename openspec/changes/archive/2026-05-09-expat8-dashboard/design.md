## Context

The dashboard already exists as a Next.js app concept that talks to the backend for mutations and uses server-side DB reads to hydrate article and vocabulary review screens. The remaining gap is packaging and deployment: the product needs the dashboard to be named and shipped as `expat8-dashboard`, with Docker/Compose able to run it beside `expat8-backend`.

Current constraints:
- Dashboard mutations must continue to use existing backend admin APIs.
- Dashboard reads can remain server-side until dedicated admin read endpoints are added.
- Compose already manages PostgreSQL and backend; adding a dashboard service should not destabilize that deployment.
- The dashboard needs browser-friendly auth handling and a clear runtime config surface for backend URL and admin credentials.

Stakeholders:
- Operators need a single Compose stack that starts backend + dashboard + database.
- Content editors need the dashboard to remain fast and focused on article moderation.
- Backend maintainers want to avoid duplicating business logic in the browser.

## Goals / Non-Goals

**Goals:**
- Rename the dashboard app/service to `expat8-dashboard`.
- Make the dashboard runnable as a Docker service alongside backend and PostgreSQL.
- Keep the dashboard thin: UI, server-side hydration, and mutation orchestration only.
- Keep the deployment surface environment-driven so backend URL, database URL, and admin credentials are configurable.

**Non-Goals:**
- Rewriting backend admin APIs.
- Moving vocabulary review logic into the browser.
- Introducing a separate BFF unless it is required later for browser auth hardening.

## Decisions

### Decision 1: Rename the dashboard package and service to `expat8-dashboard`
- Choice: Update app/package/service naming to `expat8-dashboard`.
- Rationale: Gives the dashboard a deployable product identity and aligns documentation with the actual service.
- Alternatives considered: keep `web-admin`, alias it in docs only.
- Rejected because: naming drift would continue to confuse operators and deployment scripts.

### Decision 2: Deploy the dashboard as a separate Docker service
- Choice: Add a dedicated dashboard service to root Compose next to backend and PostgreSQL.
- Rationale: The dashboard has its own runtime, build, and environment requirements.
- Alternatives considered: bundle dashboard into backend container, or run it outside Compose.
- Rejected because: bundling creates unnecessary coupling and running it separately complicates local ops.

### Decision 3: Keep server-side DB reads for dashboard hydration
- Choice: Preserve server-side reads for article list/detail and vocabulary review hydration.
- Rationale: The current backend API does not have full read coverage for those dashboard screens yet.
- Alternatives considered: add new backend read endpoints first, or infer detail state from list endpoints only.
- Rejected because: the first expands backend scope and the second produces an incomplete UI.

### Decision 4: Keep mutations routed through backend admin APIs
- Choice: Dashboard creates/publishes/reviews items by calling backend admin endpoints.
- Rationale: Backend remains the source of truth for workflow transitions and auditability.
- Alternatives considered: write to the database directly from the dashboard, or duplicate business logic client-side.
- Rejected because: direct DB writes bypass validations and audit behavior.

### Decision 5: Use environment-driven runtime config for deployment
- Choice: Pass backend URL, database URL, app credentials, and admin token via environment variables.
- Rationale: Docker/Compose should stay portable across local and staging environments.
- Alternatives considered: hard-code service URLs or bake credentials into the image.
- Rejected because: that would make deployment brittle and insecure.

## Risks / Trade-offs

- [Browser auth complexity] → Mitigation: keep the first version direct and env-driven; introduce a BFF only if browser auth becomes painful.
- [Docker stack drift between backend and dashboard] → Mitigation: keep both services in the same Compose file and document shared environment variables.
- [Incomplete backend read endpoints] → Mitigation: use server-side DB reads for MVP hydration and avoid inventing new API behavior.
- [Name churn in docs and scripts] → Mitigation: rename the package/service consistently in one pass.

## Migration Plan

1. Rename the dashboard app/package/service identifiers from `web-admin` to `expat8-dashboard`.
2. Update the dashboard build/runtime configuration for Docker execution.
3. Extend root Compose with a dashboard service that points at the backend and database.
4. Update docs and operator references to use the new service name.
5. Validate the dashboard build and Compose startup locally.

Rollback strategy:
- Remove the dashboard service from Compose and restore the previous package name if necessary.
- Backend and PostgreSQL remain unchanged, so rollback is isolated to the dashboard service.

## Open Questions

- Should the dashboard remain directly signed against backend admin APIs, or should a BFF be introduced later for browser auth hardening?
- Do we want the dashboard to be built from the current Next.js app directory layout as-is, or should the package name change be accompanied by a directory rename too?
- Should Compose expose the dashboard on a fixed host port or let operators configure it the same way backend port is configured?
