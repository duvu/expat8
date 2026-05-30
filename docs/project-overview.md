# Project Overview

Expat8 is an offline-first vocabulary learning MVP for Vietnamese learners. The workspace contains a Flutter app, a Node.js backend, a Next.js admin dashboard, shared API contracts, and operational documentation.

## Repository Shape

- `mobile/` — Flutter app using Dart and ObjectBox local storage.
- `backend/` — Node.js 22 + Express 5 API service using ESM modules and `node:test`.
- `expat8-dashboard/` — Next.js 15 admin dashboard using TypeScript and React 19.
- `contracts/` — canonical mobile/backend API contract.
- `docs/` — product, architecture, operations, and implementation documentation.
- `openspec/` — OpenSpec proposal/spec/task artifacts.

## Current Product Scope

The v1 milestone includes:

- Offline-first vocabulary learning with local ObjectBox storage.
- Swipe and fill-in-the-blank study modes.
- Adaptive English CEFR and Chinese HSK proficiency.
- Optional account registration/sign-in while preserving anonymous device learning.
- Study-event sync with offline queueing and idempotent server handling.
- User-submitted vocabulary enrichment.
- Article-based vocabulary extraction, review, and publishing.
- Speaking foundation drills without audio upload.
- Weekly speaking summary.
- Vocabulary exam with shareable certificates.
- Admin review workflows through the dashboard.
- HMAC app credential protection for `/v1/*` requests.

## Source of Truth Rules

- [`contracts/api.md`](../contracts/api.md) wins over implementation code for API behavior.
- [`backend/db/schema.sql`](../backend/db/schema.sql) is the authoritative schema for fresh local Compose databases.
- [`backend/db/migrations/`](../backend/db/migrations/) contains numbered migrations that are verified but not auto-applied by Compose.
- Mobile `--dart-define` values are compiled into the app binary; changing backend URL, app credential id/secret, timeout, or log level requires a rebuild.

## Runtime Ownership

- Backend owns account identity, article content, vocabulary inventory, study events, SRS state, proficiency, exam sessions, certificates, and admin data.
- Mobile is the local execution/cache layer. It stores vocabulary, study events, settings, sync queue entries, logs, and device/session state in ObjectBox.
- Dashboard is the admin surface for article management, vocabulary review, and speaking prompt review.
- Background workers handle article/vocabulary enrichment outside user-facing request paths.

## Security Model Summary

- All non-OPTIONS `/v1/*` requests require `x-expat8-*` app credential headers.
- Unsigned exceptions are `GET /health`, `GET /health/ready`, CORS preflight `OPTIONS /v1/*`, and public certificate reads.
- Signed-in requests add `Authorization: Bearer <session_token>` while keeping the same `device_id`.
- Admin endpoints require app credentials plus an admin token configured through `ADMIN_API_TOKENS`.
- Mobile embedded secrets are abuse friction, not proof of user identity.

## High-Risk Invariants

- `POST /v1/learning/cards` must not receive mobile-provided exclusion fields such as `exclude_server_word_ids` or `current_word_id`.
- `card_mode` must be `"new"` or absent.
- Duplicate avoidance is backend-owned through learner state and `PUT /v1/user-word-cache`.
- Article processing and LLM enrichment run in workers/schedulers, not during learning-card requests.
- Production deployment uses the Z440 deployment compose file, not the repository-local compose file.
