# Deployment Guide

This guide covers local Compose deployment and the production Z440 deployment constraints captured in repo guidance.

> **Operators:** the step-by-step production procedures live in [`docs/ops/`](ops/README.md) — [deploy](ops/deploy.md), [mobile release](ops/mobile-release.md), [backup/restore](ops/backup-restore.md), [monitoring](ops/monitoring.md), [troubleshooting](ops/troubleshooting.md), [secrets](ops/secrets.md), [maintenance](ops/maintenance.md). This page is the reference behind them.

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

Then point `expat8-backend` **and** `expat8-worker` at the new tag (`EXPAT8_BACKEND_IMAGE` / `EXPAT8_WORKER_IMAGE` in `~/deployment/worker-z440/.env`), migrate, and redeploy from the deployment directory:

```bash
cd ~/deployment/worker-z440
docker compose up -d --force-recreate expat8-backend expat8-worker
```

Verify:

```bash
docker compose ps expat8-backend
curl -i -sS http://<INTERNAL_HOST>:18787/health
```

Do not treat a healthy repository-local `expat8-backend-1` container as production verification.

### Database migrations

The backend tracks applied migrations in `schema_migrations` (`backend/src/migrations.js`). On a database that predates the runner, the first run records the `schema.sql` baseline and replays every file in `backend/db/migrations/` once; all migrations are idempotent and this path is covered by `test/migrations.test.js` against PostgreSQL 16.

Production deploy step, before recreating `expat8-backend` (take a `pg_dump` first). The runner holds a session-level `pg_advisory_lock`, so connect **directly to Postgres**, not through pgbouncer (transaction pooling can strand or skip the lock):

```bash
cd ~/deployment/worker-z440
docker compose run --rm --no-deps \
  -e DATABASE_URL='postgres://<user>:<password>@postgres:5432/<expat8_db>' \
  expat8-backend npm run migrate
```

Local Compose sets `MIGRATE_ON_START=true`, so the API migrates itself on boot. The first production run also applies `20260928_speaking_loop_completed_event_type.sql`, without which PostgreSQL rejects every `loop_completed` speaking event.

### Client IP and auth rate limits

`/v1/users/register` and `/v1/users/sign-in` are rate limited per client IP and per client IP + identifier (see `contracts/api.md#rate-limits`). Production traffic for `expat8.x51.vn` reaches the backend through a reverse proxy, so without `TRUST_PROXY` every learner shares the proxy's IP and the per-IP auth limit (`AUTH_RATE_LIMIT_IP`, default 60/min) becomes a global cap.

Set `TRUST_PROXY` on `expat8-backend` to the address of the proxy that forwards to port `18787` (for example `TRUST_PROXY=10.113.213.1`, or a hop count such as `1`). Only trust addresses that overwrite `X-Forwarded-For`; because `18787` is also reachable directly on the internal network, prefer a specific address over `true`.

Verify after deploy: send a sign-in request from two different networks (e.g. Wi-Fi and mobile data); each should see its own `X-RateLimit-Remaining` value start from the per-IP cap instead of sharing one counter.

## Worker Deployment

The article worker runs as a separate service using the same backend image (same tag as `expat8-backend`) and `npm run start:worker`. It shares PostgreSQL and LiteLLM configuration with the backend service. Stopping the worker leaves queued jobs durable in PostgreSQL.

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
