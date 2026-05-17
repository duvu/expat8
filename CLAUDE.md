# OpenWolf

@.wolf/OPENWOLF.md

This project uses OpenWolf for context management. Read and follow .wolf/OPENWOLF.md every session. Check .wolf/cerebrum.md before generating code. Check .wolf/anatomy.md before reading files.


# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Expat8 is an offline-first vocabulary learning app for Vietnamese learners, built as a Flutter mobile app + Node.js backend. The backend is the source of truth for vocabulary, SRS state, and study events. Mobile uses ObjectBox for local storage.

## Repository Structure

- `mobile/` — Flutter app (Dart, ObjectBox local DB)
- `backend/` — Node.js + Express API server (ESM modules, `node:test`)
- `contracts/api.md` — Mobile-backend API contract (canonical reference)
- `openspec/` — Change proposals, design docs, and implementation tasks
- `docs/` — Architecture and technical documentation

## Backend Commands

```bash
cd backend
npm test                          # Run all tests
node --test test/api.test.js      # Run a single test file
npm start                         # Start API server (src/server.js)
npm run start:worker              # Start processing worker (src/worker.js)
```

Backend requires Node >= 22. Uses `node:test` (no external test framework). Tests are integration-style and run against in-memory `WordStore` — no database needed for most tests.

Copy `.env.example` to `.env` before running locally. Key env vars:

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `APP_CREDENTIALS_JSON` | JSON array of `{appId, secret, status}` for HMAC signing |
| `ADMIN_API_TOKENS` | Comma-separated tokens for `/v1/admin/*` access |
| `LITELLM_BASE_URL` / `LITELLM_API_KEY` | LLM enrichment (optional; falls back gracefully) |

## Mobile Commands

```bash
cd mobile
flutter test                                   # Run all tests
flutter test test/learning_session_controller_test.dart  # Single test file
flutter run \
  --dart-define=BACKEND_BASE_URL=<YOUR_BACKEND_URL> \
  --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>
```

For production Android verification, use the same define set for the signed APK and the signed bundle. Keep the real values out of the repo and inject them from your environment or secret store at build time:

```bash
cd mobile
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release \
  --dart-define=BACKEND_BASE_URL=<YOUR_BACKEND_URL> \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET> \
  --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
  --dart-define=APP_LOG_LEVEL=info
```

The APK output is `build/app/outputs/flutter-apk/app-release.apk`; the matching bundle flow remains `build/app/outputs/bundle/release/app-release.aab`. Any change to `BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, `NEW_WORD_TIMEOUT_SECONDS`, or `APP_LOG_LEVEL` requires a fresh rebuild.

Build-time values should be sourced from local environment files or a secret manager and injected at build time. Do not add real production values to GitHub-tracked docs or scripts.
Before every package build, load the current values from env/secret storage and then rebuild the APK/AAB. Never assume a previous build is still valid after changing any compile-time input.

All compile-time configuration is passed via `--dart-define`. `AppConfig.fromEnvironment()` reads these at startup.

## Docker (Local Stack)

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
curl http://localhost:8787/health
docker compose logs -f backend
docker compose down
```

PostgreSQL is auto-initialized from `backend/db/schema.sql` on first start.

## Backend Architecture

### Request Pipeline

All `/v1/*` requests are protected by HMAC app credentials (see `contracts/api.md` for the signing spec). The middleware chain in `app.js`:

1. CORS headers
2. `requestContextMiddleware` — attaches `request.log` (child logger with `request_id`)
3. `rejectMissingCredentialHeaders` — 400 if any `x-expat8-*` header is missing
4. `captureRawBody` — reads the raw body for HMAC verification (body size limits apply)
5. `appCredentialGuard` — verifies HMAC signature and nonce
6. `parseJsonFromCapturedBody` — parses JSON after verification
7. Route handlers

`GET /health` bypasses all middleware.

### Store Layer

`WordStore` (`src/word_store.js`) is an in-memory store used by tests and as the dev/fallback implementation. `PostgresWordStore` (`src/postgres_word_store.js`) is the production store. Both implement the same interface — `createApp()` accepts either as `store`.

### Key Modules

- `src/proficiency.js` — CEFR ladder logic; upgrades after 5× `too_easy`, downgrades after 5× `hard`
- `src/app_credentials.js` — HMAC signing/verification, `InMemoryNonceCache`
- `src/user_identity.js` — Password hashing, session tokens (stored as SHA256 hash server-side)
- `src/generation_service.js` / `src/litellm_client.js` — LLM integration (not in the learning card request path)
- `src/article_processing_pipeline.js` — Article ingestion: extract → normalize → LLM enrich → store
- `src/worker.js` — Background processing worker entry point

### Admin Access

Admin endpoints (`/v1/admin/*`) require `X-Expat8-Admin-Token` header matching a token in `ADMIN_API_TOKENS`. Admin routes also still require the standard app credential headers.

## Mobile Architecture

### Startup Flow

`main()` → opens ObjectBox DB → seeds bundled vocab if empty (`assets/seed_vocab/{en,zh,vi}.json`) → creates `BackendApiClient` → creates `WordRepository` → creates `LearningSessionController` → `runApp(LearningScreen)`.

Background: starts periodic inventory refresh, syncs word cache to backend.

### Key Components

- `BackendApiClient` (`src/api/`) — Signs all requests with HMAC app credentials; handles bearer session token
- `WordRepository` (`src/data/`) — ObjectBox queries, seed loading, backend sync, device ID management
- `LearningSessionController` (`src/session/`) — `ChangeNotifier` driving the UI; owns card selection, study event submission, proficiency state
- `LocalDatabase` (`src/data/local_database.dart`) — ObjectBox open/close, log persistence, pruning
- `PersistedLogger` (`src/logging/`) — Writes structured log entries to ObjectBox; pruned every 5 minutes

### Card Flow

Cards are loaded exclusively via `POST /v1/learning/cards` with `card_mode: "new"`. The mobile app does **not** send exclusion lists — duplicate avoidance is backend-owned via `user_word_cache`. After rating a card, a study event is submitted to `POST /v1/study-events` (single event) or batched via `POST /v1/study-events/sync`.

## API Design Invariants

- `POST /v1/learning/cards` must never receive client-side exclusion fields (`exclude_server_word_ids`, `current_word_id`, etc.) — backend rejects with 400
- `card_mode` must be `"new"` or absent; any other value is 400
- Study events use `client_event_id` for idempotency — submitting the same ID twice is a no-op
- Proficiency level is returned in every study event response
- `PUT /v1/user-word-cache` caps at 1000 IDs; unknown IDs are reported but not stored

## Content Ingestion Pipeline

Articles flow through statuses: `pending_processing` → `processing` → `pending_review` (admin content) or `processed` (user content). LLM enrichment happens in the worker, never in the request path. The `article_term_extractor.js` and `vocabulary_enrichment_adapter.js` modules handle extraction and LLM calls respectively.
