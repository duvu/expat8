# MVP Setup and Limitations

## Prerequisites

- Flutter SDK 3.3 or newer for the mobile app.
- Node.js 22 or newer for the backend.
- Optional LiteLLM server for live AI vocabulary generation.

## Backend

```bash
cd backend
copy .env.example .env
npm ci
npm test
npm start
```

Environment values:

- `PORT`: backend HTTP port, default `8787`.
- `DATABASE_URL`: PostgreSQL connection string. When set, the backend uses PostgreSQL-backed persistence.
- `LITELLM_BASE_URL`: LiteLLM-compatible base URL, default `<YOUR_LITELLM_URL>`.
- `LITELLM_API_KEY`: optional API key for LiteLLM. Supply this through the shell environment or an untracked local env file.
- `LITELLM_MODEL`: model routed through LiteLLM.
- `DEFAULT_SOURCE_LANGUAGE`: default source language, currently `vi`.
- `DEFAULT_TARGET_LANGUAGE`: default target language, currently `en`.
- `NEW_WORD_TIMEOUT_SECONDS`: product timeout mirrored by mobile config.
- `CORS_ALLOWED_ORIGIN`: allowed browser origin for `/v1/*` CORS responses,
  default `*` for local development. Production should set the exact web app
  origin.
- `APP_CREDENTIALS_JSON`: JSON array of active app credentials. Use a local
  placeholder only in development; real secrets must come from deployment
  secrets.
- `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS`: allowed signed timestamp skew,
  default `300`.
- `APP_CREDENTIAL_NONCE_TTL_SECONDS`: replay-protection window, default `300`.
- `APP_CREDENTIAL_GET_BODY_LIMIT_BYTES`: maximum GET body size, default `0`.
- `APP_CREDENTIAL_POST_BODY_LIMIT_BYTES`: maximum POST body size, default
  `262144`.
- `LOG_LEVEL`: backend structured log level (`debug`/`info`/`warn`/`error`),
  default `info`.
- `LOG_REDACTION_ENABLED`: redacts sensitive values in logs, default `true`.
- `VOCAB_SCHEDULER_ENABLED`: starts the backend vocabulary scheduler when the
  HTTP server starts, default `true`.
- `VOCAB_POOL_MIN_SIZE`: minimum usable words per target language before the
  scheduler switches to daily top-up, default `1000`.
- `VOCAB_FILL_INTERVAL_SECONDS`: scheduler cadence while a pool is below the
  minimum, default `60`.
- `VOCAB_DAILY_GENERATION_COUNT`: number of words generated once per day after
  the pool is full, default `10`.
- `VOCAB_DAILY_GENERATION_HOUR_UTC`: earliest UTC hour for the daily top-up,
  default `0`.
- `VOCAB_GENERATION_BATCH_SIZE`: maximum words requested per fill run, default
  `100`.
- `VOCAB_SCHEDULER_LOCK_TTL_SECONDS`: lock expiration for multi-instance
  scheduler ownership, default `120`.

All `/v1/*` requests must be signed with the app credential headers documented
in `contracts/api.md`. `/health` remains unsigned for Compose and load balancer
checks. Backend tests use a safe local fixture in
`backend/test/support/app_credential_helpers.js`; do not reuse that fixture as
a production secret.

Browser clients may send unsigned `OPTIONS` preflight requests to `/v1/*`.
Those preflight requests are answered before app credential verification, but
all non-OPTIONS `/v1/*` requests still require valid app credential headers.

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
- `POSTGRES_PASSWORD`: database password, default `<YOUR_DB_PASSWORD>`.
- `BACKEND_PORT`: host port exposed for the backend, default `8787`.
- `PORT`: backend container port, default `8787`.
- `LITELLM_BASE_URL`: default `<YOUR_LITELLM_URL>`.
- `LITELLM_API_KEY`: LiteLLM API key, intentionally blank by default.
- `LITELLM_MODEL`: default `gpt-4o-mini`.
- `CORS_ALLOWED_ORIGIN`: default `*`; set an explicit production web origin
  before exposing browser clients.
- `APP_CREDENTIALS_JSON`: app credentials passed to the backend container,
  default `[]`.
- `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS`: default `300`.
- `APP_CREDENTIAL_NONCE_TTL_SECONDS`: default `300`.
- `APP_CREDENTIAL_GET_BODY_LIMIT_BYTES`: default `0`.
- `APP_CREDENTIAL_POST_BODY_LIMIT_BYTES`: default `262144`.
- `LOG_LEVEL`: default `info`.
- `LOG_REDACTION_ENABLED`: default `true`.
- `VOCAB_SCHEDULER_ENABLED`: default `true`.
- `VOCAB_POOL_MIN_SIZE`: default `1000`.
- `VOCAB_FILL_INTERVAL_SECONDS`: default `60`.
- `VOCAB_DAILY_GENERATION_COUNT`: default `10`.
- `VOCAB_DAILY_GENERATION_HOUR_UTC`: default `0`.
- `VOCAB_GENERATION_BATCH_SIZE`: default `100`.
- `VOCAB_SCHEDULER_LOCK_TTL_SECONDS`: default `120`.

Build and deploy note:

- Any change to `BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, `NEW_WORD_TIMEOUT_SECONDS`, or `APP_LOG_LEVEL` requires rebuilding the mobile APK/AAB so the binary picks up the new compile-time values.
- Keep those mobile build values in a local env file or secret store and inject them at build time; do not commit them to GitHub.
- Any change to `DATABASE_URL`, `LITELLM_BASE_URL`, `LITELLM_API_KEY`, or `APP_CREDENTIALS_JSON` requires restarting the backend or Compose stack so the runtime picks up the new environment.

For a fresh database volume, PostgreSQL initializes tables and indexes from `backend/db/schema.sql`. To reset local Compose data, run `docker compose down -v`.

## Mobile

```bash
cd mobile
flutter pub get
flutter test
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8787 --dart-define=NEW_WORD_TIMEOUT_SECONDS=5
```

The app uses ObjectBox local persistence and stores vocabulary, study events,
settings, sync queue entries, and logs locally before sync. Linux test runs need
the ObjectBox native library available at `mobile/lib/libobjectbox.so`; see
`docs/release-notes.md` for the download note.

For release packaging, use the same current `--dart-define` values documented in `README.md` and `mobile/README.md`. Source them from your local env file or secret manager before building, and rebuild the package whenever any of those values changes.

Vocabulary refill is backend-managed:

- Mobile syncs the active local `server_word_id` inventory with
  `PUT /v1/user-word-cache`.
- Mobile can request backend-selected refill batches through
  `POST /v1/learning/cards` with `card_mode: "new"`.
- Backend batches currently return new cards for this flow and report target
  and actual mix metadata.
- `easy` writes the study event first, removes the word from `local_words`,
  syncs cache inventory, and lets the next local/backend refill supply a
  replacement.
- Startup and inventory top-up/rotation use the same backend-selected card path
  and capped ObjectBox write path.

The mobile app supports optional registration/sign-in. Anonymous learning uses
the persisted `device_id`; signed-in learning keeps that `device_id` and adds a
bearer session token to eligible feed, study-event, sync, and proficiency
requests.

Manual word capture:

- The learning drawer exposes an `Add word` flow for learner-entered words or
  short expressions.
- Mobile stores those submissions locally first, then syncs them through
  `POST /v1/user-submitted-words` and refreshes status through
  `GET /v1/user-submitted-words`.
- Submission lifecycle is `queued`, `processing`, `ready`, or `failed`.
- When a submission becomes `ready`, the resolved canonical word is inserted
  into the normal local vocabulary inventory and becomes part of the standard
  study flow.

Auth UX behavior:

- Register, sign-in, and sign-out show SnackBar feedback for success and
  failure.
- Duplicate auth submissions are ignored while an auth action is in progress.
- Register/sign-in failures keep the previous valid session, or remain
  anonymous when no session existed.
- Sign-out clears the local session even if server confirmation fails, then
  shows that the app signed out locally.
- The drawer shows signed-in user info using `displayName` first and
  `identifier` as fallback. Stored sessions loaded on app start render the same
  user info.

Swipe behavior:

- Right-to-left requests a new word.
- Left-to-right requests a recent/due review word.
- Slow drags are accepted using a drag-distance threshold, not only velocity.
- The learning screen also exposes explicit `New Word` and `Review` actions.
- If local new/review lookup misses, the stale card is cleared and a no-card
  message is rendered.

## Smoke Test Coverage

Backend tests include a service-level smoke test that simulates:

- Fetching learning cards from `POST /v1/learning/cards`.
- Saving it into a client-side local cache.
- Rating the word and adding a study event to a sync queue.
- Posting the event to `/v1/study-events/sync`.
- Verifying the backend stores the event idempotently.

Read-only deployed smoke check:

```bash
node scripts/smoke-deployed-backend.mjs
```

Optional environment:

- `BACKEND_BASE_URL`: defaults to `<YOUR_BACKEND_URL>`.
- `APP_CREDENTIAL_APP_ID`: defaults to the mobile app credential id.
- `APP_CREDENTIAL_SECRET`: defaults to the mobile app credential secret.
- `SMOKE_TIMEOUT_MS`: defaults to `5000`.

The script verifies unsigned `/health`, unsigned `/v1/words/recent` rejection,
and signed `/v1/words/recent`. For HTTPS URLs, Node validates the certificate
chain by default; TLS trust failures are reported as smoke failures.

## Known MVP Limitations

- Optional registration/sign-in is implemented with backend sessions. OAuth,
  magic-link login, password reset, and multi-factor authentication are not in
  this MVP.
- App credential checks protect `/v1/*` from unsigned requests, but they are
  not user authentication and do not prove human identity. User sessions are
  resolved only after the app credential layer passes.
- The backend uses PostgreSQL when `DATABASE_URL` is set. Unit tests still use an in-memory store by default, and PostgreSQL integration tests run when `TEST_DATABASE_URL` is provided.
- Nonce replay protection is in-memory for the current single-instance backend.
  Multi-instance deployments need a shared nonce store such as Redis.
- Flutter tests that touch local persistence require the ObjectBox native
  library for the host platform.
- No pronunciation audio or speech scoring is included.
- AI generation runs outside mobile request handling. Scheduler failures are
  logged without secrets/user payloads and retried later; mobile card responses
  continue to read only stored database words.
