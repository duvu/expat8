# AGENTS.md

## Repo Shape
- `mobile/` — Flutter app (Dart, ObjectBox, SDK `>=3.3.0 <4.0.0`)
- `backend/` — Node.js 22 + Express 5, ESM (`"type": "module"`), `node:test` only (no Jest/Mocha)
- `expat8-dashboard/` — Next.js 15 admin web app (TypeScript, React 19); already wired in `docker-compose.yml`
- `contracts/api.md` — canonical API reference; wins over code when they conflict
- `backend/db/schema.sql` — authoritative DB schema; auto-applied by Compose on first start
- `backend/db/migrations/` — numbered SQL migrations; NOT auto-applied; verified via `npm run verify:migrations`

## Commands

### Backend
```bash
cd backend && npm test                        # all tests (node --test, no DB required for most)
cd backend && node --test test/api.test.js    # single file
cd backend && npm run start:worker            # article processing worker (separate process)
cd backend && npm run verify:migrations       # check migration content integrity
```
- PostgreSQL integration tests (`postgres_integration.test.js`) only run when `TEST_DATABASE_URL` is set; skip silently otherwise.
- `backend/test/e2e_prod_test.mjs` is a **manual production smoke test**; it is NOT part of `npm test`.

### Mobile
```bash
cd mobile && flutter test
cd mobile && flutter test test/learning_session_controller_test.dart  # single file
cd mobile && flutter pub run build_runner build --delete-conflicting-outputs  # after ObjectBox entity changes
```
- Linux desktop tests require `mobile/lib/libobjectbox.so` to be present.

### Dashboard
```bash
cd expat8-dashboard && npm run dev    # dev server (port 3000)
cd expat8-dashboard && npm run build
cd expat8-dashboard && npm run lint
```

### Local Stack
```bash
LITELLM_API_KEY=... docker compose up --build -d
```

## Non-Obvious Constraints

### API Auth
- All `/v1/*` requests require HMAC app-credential headers (`x-expat8-*`); missing → 400.
- Unsigned exceptions: `GET /health`, `GET /health/ready`, `OPTIONS /v1/*` (CORS preflight), and `GET /v1/exam/certificate/:id` (fully public, no headers at all).
- Signed-in requests keep the same `device_id` and add `Authorization: Bearer <session_token>`.
- `ADMIN_API_TOKENS` env var grants access to `/v1/admin/*` endpoints (checked after app credential verification → 403 if absent).

### Card Loading
- `POST /v1/learning/cards` must NOT include `exclude_server_word_ids`, `current_word_id`, or any exclusion fields → 400.
- `card_mode` must be `"new"` or absent; any other value → 400.
- Duplicate avoidance is backend-owned via learner state and `PUT /v1/user-word-cache` (cap: 1000 IDs).

### Admin Articles
- `PATCH /v1/admin/articles/:id` `visibility` accepts only `"private"` or `"published"`; `"shared"` → 400.

### Exam
- `POST /v1/exam/start` requires ≥ 5 studied words (`422 INSUFFICIENT_WORDS`), capped at 20 questions.
- Exam sessions expire after 2 hours (`410 SESSION_EXPIRED`).
- Passing score ≥ 70%; triggers certificate issuance.

### Mobile Build
- `BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, and other `--dart-define` values are compiled into the binary — **any change requires a full rebuild**.
- Android emulator cannot reach LAN/VPN IPs (`10.x.x.x`); use a public URL for emulator builds; LAN IPs only work on physical devices.

## Backend Architecture
- `backend/src/server.js` — thin entrypoint; delegates to `createBackendRuntime()` in `src/runtime.js`
- `backend/src/runtime.js` — wires store (`PostgresWordStore` when `DATABASE_URL` set; in-memory `WordStore` otherwise), scheduler, and server
- `backend/src/app.js` — Express app factory
- `backend/src/worker.js` — background article processing; run as a separate process
- Request pipeline (all `/v1/*`): CORS → requestContext → rejectMissingCredentialHeaders → captureRawBody → appCredentialGuard → parseJsonFromCapturedBody → route handlers

## Key Environment Variables
| Variable | Notes |
|---|---|
| `DATABASE_URL` | PostgreSQL; if unset, backend uses in-memory store |
| `TEST_DATABASE_URL` | Enables `postgres_integration.test.js` |
| `APP_CREDENTIALS_JSON` | JSON array `[{appId, secret, status}]` for HMAC signing |
| `ADMIN_API_TOKENS` | Comma-separated tokens for `/v1/admin/*` |
| `LITELLM_BASE_URL` / `LITELLM_API_KEY` / `LITELLM_MODEL` | LLM enrichment (optional) |
| `CORS_ALLOWED_ORIGIN` | Defaults to `*`; set exact origin in production |

## Deploy
- Production target: `~/deployment/worker-z440/docker-compose.yml` (NOT the repo's local compose).
- Production backend port: `18787` (local dev: `8787`).
- Tag convention: `YYYYMMDD.HHMM`.
- Full deploy sequence in `.github/copilot-instructions.md`.

## Reference Files
- `CLAUDE.md` and `.github/copilot-instructions.md` — deploy/build details.
- `.wolf/*` — active OpenWolf memory; update when you learn something durable.
- `contracts/api.md` — trust this over handler code for API behavior.
