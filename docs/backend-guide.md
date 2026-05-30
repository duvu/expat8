# Backend Guide

The backend is a Node.js 22 + Express 5 service in `backend/`. It uses ESM modules, `node:test`, and either an in-memory store or PostgreSQL-backed persistence.

## Commands

```bash
cd backend
npm test
node --test test/api.test.js
npm start
npm run start:worker
npm run verify:migrations
npm run lint
npm run format:check
```

PostgreSQL integration tests run only when `TEST_DATABASE_URL` is set.

## Entry Points

- `src/server.js` — thin API server entrypoint.
- `src/runtime.js` — loads config, selects store, wires scheduler/runtime, and creates the server.
- `src/app.js` — Express app factory and route registration.
- `src/worker.js` — background article-processing worker entrypoint.

## Store Selection

- If `DATABASE_URL` is set, runtime uses `PostgresWordStore`.
- If `DATABASE_URL` is unset, runtime uses the in-memory `WordStore`.
- Most tests use in-memory state for speed and isolation.

## Authentication Layers

All `/v1/*` routes require app credential headers unless explicitly exempted in the API contract. User sessions are layered inside app credentials:

- Anonymous learning requests keep a stable `device_id`.
- Signed-in requests add `Authorization: Bearer <session_token>` and keep the same `device_id`.
- Admin requests also require `X-Expat8-Admin-Token` matching `ADMIN_API_TOKENS`.

## Important Environment Variables

| Variable | Purpose |
|---|---|
| `PORT` | Backend HTTP port, default `8787`. |
| `DATABASE_URL` | PostgreSQL connection string; unset uses in-memory store. |
| `TEST_DATABASE_URL` | Enables PostgreSQL integration tests. |
| `APP_CREDENTIALS_JSON` | HMAC app credentials as `[{appId, secret, status}]`. |
| `ADMIN_API_TOKENS` | Comma-separated admin tokens. |
| `LITELLM_BASE_URL` / `LITELLM_API_KEY` / `LITELLM_MODEL` | Optional LLM enrichment configuration. |
| `CORS_ALLOWED_ORIGIN` | Browser CORS origin, default `*`. |
| `LOG_ARCHIVE_DIR` | Storage path for uploaded mobile log archives. |
| `LOG_ARCHIVE_RETENTION_DAYS` | Log archive retention window. |
| `ARTICLE_WORKER_INTERVAL_MS` | Worker polling interval. |
| `ARTICLE_WORKER_MAX_ATTEMPTS` | Worker retry limit per article job. |

## Database

- Fresh local Compose databases initialize from `backend/db/schema.sql`.
- Numbered SQL migrations live under `backend/db/migrations/`.
- Validate migration content with `npm run verify:migrations`.
- Local Compose does not automatically apply migrations after the first database-volume initialization.

## Key Domain Areas

- App credentials and nonce replay protection.
- User registration, sign-in, sign-out, and session lookup.
- Study event submission and sync.
- Adaptive proficiency and card selection.
- User word cache and duplicate avoidance.
- User-submitted vocabulary enrichment.
- Article ingestion, processing jobs, vocabulary review, and publishing.
- Speaking prompt/event/summary APIs.
- Vocabulary exam sessions, answers, results, and certificates.
- Mobile log archive upload and admin retrieval.

## Backend-Owned Learning Invariants

- `POST /v1/learning/cards` accepts `card_mode: "new"` or omitted.
- Exclusion fields from the mobile client are rejected.
- `PUT /v1/user-word-cache` caps tracked server word ids at 1000.
- Study events use client ids for idempotency.
- Proficiency updates are based on rating streaks and persisted learner state.

## Worker Notes

The worker should run as a separate process from the API server:

```bash
cd backend
npm run start:worker
```

In Compose, the worker is the `article-worker` service. In production, the worker uses the same backend image but a different command/service definition.
