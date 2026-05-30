# Architecture Guide

Expat8 is organized around an offline-first mobile client, a backend source of truth, a web admin surface, and background processing for expensive content work.

```text
Flutter mobile app ─┐
                    ├─ signed HTTP /v1/* ─ Backend API ─ PostgreSQL
Next.js dashboard ──┘                         │
                                               ├─ article worker
                                               └─ optional LiteLLM enrichment
```

## Applications

### Mobile

The Flutter app is the learner-facing client. It opens ObjectBox on startup, seeds bundled vocabulary when needed, keeps a stable device id, signs backend requests with app credentials, and queues local work for sync.

### Backend

The backend is a Node.js 22 + Express 5 service. `backend/src/runtime.js` wires config, store selection, schedulers, and the HTTP server. `backend/src/app.js` builds the Express app and middleware chain.

### Dashboard

The dashboard is a Next.js 15 admin app for article management, vocabulary review, and operational/admin workflows. It is included in the root `docker-compose.yml` as `expat8-dashboard`.

### Worker

The article worker runs separately from the API process with `npm run start:worker`. It claims queued article-processing work, extracts candidate terms, enriches vocabulary, validates output, and persists reviewable items.

## Request Pipeline

All `/v1/*` backend requests follow this high-level path:

1. CORS handling.
2. Request context and structured logging.
3. Missing credential header rejection.
4. Raw-body capture for signing.
5. App credential HMAC verification and nonce replay protection.
6. JSON parsing from the captured raw body.
7. Route handler execution.

Unsigned exceptions are health/readiness endpoints, CORS preflight, and the public certificate endpoint documented in the API contract.

## Storage Model

- PostgreSQL stores durable backend state in deployed/local Compose environments.
- `WordStore` provides an in-memory implementation used by most tests and fallback runtime scenarios.
- `PostgresWordStore` provides the production PostgreSQL-backed store.
- ObjectBox stores mobile-local words, study events, settings, sync queue entries, logs, and local session/device state.

## Learning Flow

1. Mobile requests cards with `POST /v1/learning/cards`.
2. Backend selects new cards based on learner state and proficiency.
3. Mobile stores/uses cards locally and records learner ratings.
4. Mobile submits study events immediately or through a sync queue.
5. Backend applies idempotency and updates SRS/proficiency state.
6. Mobile syncs local inventory through `PUT /v1/user-word-cache` so backend can avoid duplicates.

The mobile app does not send exclusion lists when requesting learning cards.

## Content Ingestion Flow

1. User/admin submits article content.
2. Backend stores the article and queues processing.
3. Worker extracts terms/phrases and enriches them through deterministic validation plus optional LiteLLM.
4. Admin content moves toward review/publish workflows; private user content can become available to that user.
5. Learning-card requests read stored vocabulary only.

## Proficiency and Exams

- English uses CEFR levels from A1 to C2.
- Chinese uses HSK levels from HSK1 to HSK6.
- Five consecutive `too_easy` ratings move the learner up one level.
- Five consecutive `hard` ratings move the learner down one level.
- Exam start requires at least five studied words and caps sessions at twenty questions.
- Exam sessions expire after two hours; passing score is at least 70%.

## Operational Boundaries

- Local Compose is for development and smoke testing.
- Production backend deployment targets the Z440 deployment compose file under `~/deployment/worker-z440/docker-compose.yml`.
- Mobile release artifacts must be rebuilt after compile-time configuration changes.
- Migrations are verified with `npm run verify:migrations`; they are not automatically applied by local Compose after the initial schema load.
