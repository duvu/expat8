# Deployment Guide

This guide covers local Compose deployment and the production Z440 deployment constraints captured in repo guidance.

## Local Compose Stack

From the repository root:

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
curl http://localhost:8787/health
docker compose logs -f backend
docker compose down
```

Services:

- `postgres` — PostgreSQL 16, initialized from `backend/db/schema.sql` on first start.
- `backend` — Express API built from `backend/`, exposed on `BACKEND_PORT` or `8787`.
- `article-worker` — background worker using the backend image and `npm run start:worker`.
- `expat8-dashboard` — Next.js dashboard exposed on `DASHBOARD_PORT` or `3000`.

Use `docker compose down -v` only when intentionally deleting local database volume state.

## Production Backend Target

Production backend deployment targets the Z440 deployment directory, not the repository-local compose file:

```text
~/deployment/worker-z440/docker-compose.yml
```

Production backend port is `18787`. Local development defaults to `8787`.

## Backend Image Deploy Sequence

Use timestamp image tags in `YYYYMMDD.HHMM` format.

```bash
docker build -t <YOUR_REGISTRY>/expat8-backend:<TAG> backend
docker push <YOUR_REGISTRY>/expat8-backend:<TAG>
```

Then update the Z440 deployment compose file so `expat8-backend` uses the new image tag, and redeploy from the deployment directory:

```bash
cd ~/deployment/worker-z440
docker compose up -d --force-recreate expat8-backend
```

Verify:

```bash
docker compose ps expat8-backend
curl -i -sS http://<INTERNAL_HOST>:18787/health
```

Do not treat a healthy repository-local `expat8-backend-1` container as production verification.

## Worker Deployment

The article worker should run as a separate service using the same backend image and `npm run start:worker`. It shares PostgreSQL and LiteLLM configuration with the backend service. Stopping the worker leaves queued jobs durable in PostgreSQL.

## Environment and Secrets

Runtime values that require service restart/recreate after changes include:

- `DATABASE_URL`.
- `APP_CREDENTIALS_JSON`.
- `ADMIN_API_TOKENS`.
- `LITELLM_BASE_URL`, `LITELLM_API_KEY`, `LITELLM_MODEL`.
- Worker interval/retry settings.
- Dashboard backend/admin/app credential values.

Do not commit real secrets, keystores, service-account files, or credential JSON. Use deployment secrets or untracked env files.

## Mobile Release Deployment

Mobile release builds compile configuration into the binary. If any of these change, rebuild APK and AAB before testing or release:

- `BACKEND_BASE_URL`.
- `APP_CREDENTIAL_APP_ID`.
- `APP_CREDENTIAL_SECRET`.
- `NEW_WORD_TIMEOUT_SECONDS`.
- `APP_LOG_LEVEL`.

Use a public backend URL for Android emulator builds. LAN/VPN IPs are suitable only for physical devices on the same network.

## Smoke Checks

- Backend health: `GET /health`.
- Backend readiness: `GET /health/ready`.
- Signed API request with valid app credential headers.
- Admin API request with both app credentials and admin token.
- Worker logs showing job polling/claim/completion when article jobs exist.
- Dashboard page load against the intended backend URL.
- Mobile installed artifact using the intended compiled backend URL and credentials.
