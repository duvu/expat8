# Developer Setup

This guide describes the local development setup for the full Expat8 workspace.

## Prerequisites

- Node.js 22 or newer for `backend/` and `expat8-dashboard/`.
- Flutter SDK compatible with Dart `>=3.3.0 <4.0.0` for `mobile/`.
- Docker and Docker Compose for the local PostgreSQL/backend/dashboard stack.
- Java 21 for Android release builds.
- `mobile/lib/libobjectbox.so` for Flutter/Linux tests that touch ObjectBox.

## Install Dependencies

Backend:

```bash
cd backend
npm install
```

Dashboard:

```bash
cd expat8-dashboard
npm install
```

Mobile:

```bash
cd mobile
flutter pub get
```

## Local Backend

The backend can run with an in-memory store when `DATABASE_URL` is unset, or with PostgreSQL when `DATABASE_URL` is configured.

```bash
cd backend
npm test
npm start
```

Important environment variables:

- `PORT` — HTTP port, default `8787`.
- `DATABASE_URL` — PostgreSQL connection string; unset uses in-memory store.
- `APP_CREDENTIALS_JSON` — JSON array of `{appId, secret, status}` entries.
- `ADMIN_API_TOKENS` — comma-separated admin tokens for `/v1/admin/*`.
- `LITELLM_BASE_URL`, `LITELLM_API_KEY`, `LITELLM_MODEL` — optional LLM enrichment config.
- `CORS_ALLOWED_ORIGIN` — browser CORS origin, default `*` for development.

## Local Compose Stack

From the repository root:

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
curl http://localhost:8787/health
docker compose logs -f backend
docker compose down
```

The stack starts:

- `postgres` on an internal network, initialized from `backend/db/schema.sql` on first volume creation.
- `backend` on `http://localhost:${BACKEND_PORT:-8787}`.
- `article-worker` using `npm run start:worker`.
- `expat8-dashboard` on `http://localhost:${DASHBOARD_PORT:-3000}`.

Reset local database state with `docker compose down -v` only when you intentionally want to delete local Compose data.

## Local Mobile Run

Mobile configuration is compile-time. Pass values with `--dart-define` every time they differ from defaults:

```bash
cd mobile
flutter run \
  --dart-define=BACKEND_BASE_URL=http://localhost:8787 \
  --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>
```

Android emulator builds cannot reach LAN/VPN IPs such as `10.x.x.x`; use a public URL for emulator builds. LAN IPs are only suitable for physical devices on the same network.

## Local Dashboard Run

```bash
cd expat8-dashboard
npm run dev
```

Common environment variables:

- `BACKEND_BASE_URL` — backend URL used by the dashboard server/runtime.
- `EXPAT8_DASHBOARD_DATABASE_URL` — PostgreSQL connection string for dashboard DB access.
- `ADMIN_TOKEN` — admin token sent to backend admin endpoints.
- `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET` — dashboard app credential used when signing backend requests.

## ObjectBox Code Generation

After changing ObjectBox entities in the mobile app, regenerate generated bindings:

```bash
cd mobile
flutter pub run build_runner build --delete-conflicting-outputs
```

## Secret Hygiene

- Do not commit `.env`, `.env.*`, app secrets, keystores, service-account JSON, or credential files.
- Use local env files or a secret manager for real app credentials and release signing values.
- Documentation should use placeholders such as `<YOUR_APP_SECRET>` and never real production values.
