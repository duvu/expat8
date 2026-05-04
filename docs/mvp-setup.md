# MVP Setup and Limitations

## Prerequisites

- Flutter SDK 3.3 or newer for the mobile app.
- Node.js 22 or newer for the backend.
- Optional LiteLLM server for live AI vocabulary generation.

The current development machine used for this implementation has Node.js available but does not have Flutter or Dart on `PATH`, so only backend tests can be executed here.

## Backend

```bash
cd backend
copy .env.example .env
npm test
npm start
```

Environment values:

- `PORT`: backend HTTP port, default `8787`.
- `DATABASE_URL`: PostgreSQL connection string. When set, the backend uses PostgreSQL-backed persistence.
- `LITELLM_BASE_URL`: LiteLLM-compatible base URL, default `https://lite.x51.vn`.
- `LITELLM_API_KEY`: optional API key for LiteLLM. Supply this through the shell environment or an untracked local env file.
- `LITELLM_MODEL`: model routed through LiteLLM.
- `DEFAULT_SOURCE_LANGUAGE`: default source language, currently `vi`.
- `DEFAULT_TARGET_LANGUAGE`: default target language, currently `en`.
- `NEW_WORD_TIMEOUT_SECONDS`: product timeout mirrored by mobile config.
- `APP_CREDENTIALS_JSON`: JSON array of active app credentials. Use a local
  placeholder only in development; real secrets must come from deployment
  secrets.
- `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS`: allowed signed timestamp skew,
  default `300`.
- `APP_CREDENTIAL_NONCE_TTL_SECONDS`: replay-protection window, default `300`.
- `APP_CREDENTIAL_GET_BODY_LIMIT_BYTES`: maximum GET body size, default `0`.
- `APP_CREDENTIAL_POST_BODY_LIMIT_BYTES`: maximum POST body size, default
  `262144`.

All `/v1/*` requests must be signed with the app credential headers documented
in `contracts/api.md`. `/health` remains unsigned for Compose and load balancer
checks. Backend tests use a safe local fixture in
`backend/test/support/app_credential_helpers.js`; do not reuse that fixture as
a production secret.

## Docker Compose Backend Deployment

From the repository root:

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
curl http://localhost:8787/health
docker compose logs -f backend
docker compose down
```

Compose services:

- `postgres`: PostgreSQL 16 with a persistent `postgres_data` volume.
- `backend`: Node.js 22 backend image built from `backend/Dockerfile`.

Compose environment values:

- `POSTGRES_DB`: database name, default `expat8`.
- `POSTGRES_USER`: database user, default `expat8`.
- `POSTGRES_PASSWORD`: database password, default `expat8_password`.
- `BACKEND_PORT`: host port exposed for the backend, default `8787`.
- `PORT`: backend container port, default `8787`.
- `LITELLM_BASE_URL`: default `https://lite.x51.vn`.
- `LITELLM_API_KEY`: LiteLLM API key, intentionally blank by default.
- `LITELLM_MODEL`: default `gpt-4o-mini`.
- `APP_CREDENTIALS_JSON`: app credentials passed to the backend container,
  default `[]`.
- `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS`: default `300`.
- `APP_CREDENTIAL_NONCE_TTL_SECONDS`: default `300`.
- `APP_CREDENTIAL_GET_BODY_LIMIT_BYTES`: default `0`.
- `APP_CREDENTIAL_POST_BODY_LIMIT_BYTES`: default `262144`.

For a fresh database volume, PostgreSQL initializes tables and indexes from `backend/db/schema.sql`. To reset local Compose data, run `docker compose down -v`.

## Mobile

```bash
cd mobile
flutter pub get
flutter test
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8787 --dart-define=NEW_WORD_TIMEOUT_SECONDS=5
```

The app uses a local SQLite database via `sqflite` and stores vocabulary, study events, and sync queue entries locally before sync.

## Smoke Test Coverage

Backend tests include a service-level smoke test that simulates:

- Fetching a new word from `/v1/words/next`.
- Saving it into a client-side local cache.
- Rating the word and adding a study event to a sync queue.
- Posting the event to `/v1/study-events/sync`.
- Verifying the backend stores the event idempotently.

## Known MVP Limitations

- No authentication is implemented. Server records use `device_id` and keep `user_id` nullable for future auth.
- App credential checks protect `/v1/*` from unsigned requests, but they are
  not user authentication and do not prove human identity.
- The backend uses PostgreSQL when `DATABASE_URL` is set. Unit tests still use an in-memory store by default, and PostgreSQL integration tests run when `TEST_DATABASE_URL` is provided.
- Nonce replay protection is in-memory for the current single-instance backend.
  Multi-instance deployments need a shared nonce store such as Redis.
- The Flutter project is source-scaffolded but Android/iOS platform folders were not generated because Flutter SDK is unavailable in this environment.
- No pronunciation audio or speech scoring is included.
- AI generation failures are logged without user payloads and the backend can still serve stored seed words.
