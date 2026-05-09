## Why

We already have a functional dashboard implementation, but the product now needs a single deployable `expat8-dashboard` service that operators can run beside `expat8-backend` in Docker. The current naming and packaging are fragmented, which makes deployment, documentation, and environment setup harder than they need to be.

## What Changes

- Rename the dashboard app/package/service surface from `web-admin` to `expat8-dashboard`.
- Package the dashboard as a Dockerized service that can run in the same Compose stack as `expat8-backend`.
- Keep the dashboard focused on article upload, article status, vocabulary review, and publish actions.
- Preserve the current architecture where dashboard writes go through backend admin APIs while reads can be hydrated server-side.
- **BREAKING**: service/package names, deployment references, and operator docs must switch to `expat8-dashboard`.

## Capabilities

### New Capabilities
- `expat8-dashboard`: Docker-deployable browser dashboard for admin article upload, review, and publish workflows.

### Modified Capabilities
- `admin-web-dashboard`: Rename and repurpose the dashboard capability to match the `expat8-dashboard` deployment and naming.
- `backend-container-deployment`: Extend root Compose to orchestrate the dashboard service alongside backend and PostgreSQL.

## Impact

- Frontend: dashboard package/service naming, app shell, and deployment artifacts change.
- Backend: no functional API changes required for the core admin flow.
- Docker/ops: Compose will run a new dashboard service next to backend and PostgreSQL.
- Documentation: operator and architecture references must use the new service name.
