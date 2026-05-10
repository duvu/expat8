## 1. Data Model and Migrations

- [x] 1.1 Create additive migrations for `articles`, `article_processing_jobs`, `terms`, `word_senses`, `article_terms`, and `content_packs` tables
- [x] 1.2 Add idempotency/ordering indexes and constraints for study events (`event_id` uniqueness and projection ordering support)
- [x] 1.3 Add migration verification scripts and rollback-safe checks for non-destructive deployment

## 2. API Surface for Ingestion and Admin Review

- [x] 2.1 Implement `POST/GET /v1/articles` and `GET /v1/articles/:id` with ownership enforcement
- [x] 2.2 Implement admin article workflow endpoints (`/v1/admin/articles`, reprocess, publish) with role checks
- [x] 2.3 Implement admin vocabulary review endpoints for approve/reject/edit actions with audit metadata

## 3. Processing Worker Pipeline

- [x] 3.1 Implement queue consumer skeleton and article status transitions (`pending_processing` → `processing` → terminal states)
- [x] 3.2 Implement extraction + normalization + dedup pipeline stages and persistence wiring
- [x] 3.3 Implement LLM enrichment adapter with strict schema validation and failure classification
- [x] 3.4 Persist processing run metrics/errors and enforce safe retry/dead-letter behavior

## 4. Learning Cards and Content Pack Serving

- [x] 4.1 Implement learning card selector service that prioritizes due review and controlled new cards from persisted vocabulary
- [x] 4.2 Remove/guard any runtime LLM generation from learning-card/new-word request path
- [x] 4.3 Implement content-pack version list/download endpoints and publication eligibility filters

## 5. Study Event Sync and SRS Projection

- [x] 5.1 Update study event sync contract to return accepted/duplicate/rejected classifications per event
- [x] 5.2 Implement deterministic projection ordering `(occurred_at, received_at, event_id)` for out-of-order replay
- [x] 5.3 Ensure unknown references are rejected per-event without aborting valid events in same batch

## 6. Mobile Sync Contract Alignment

- [x] 6.1 Update mobile backend client/repository contract for content-pack version sync and new sync response shape
- [x] 6.2 Ensure visible card path remains local-first while background workers handle refill and event sync
- [x] 6.3 Add diagnostics for sync failure/retry/non-blocking session continuity

## 7. Security, Limits, and Observability

- [x] 7.1 Add replay protection storage integration (Redis preferred, PostgreSQL fallback) for new write endpoints
- [x] 7.2 Apply per-endpoint rate limits for auth, article upload, learning cards, and study event sync
- [x] 7.3 Add metrics/logging for processing backlog, enrichment validation failures, and sync outcome counts

## 8. Validation and Rollout

- [x] 8.1 Add integration tests covering article ingest, processing state transitions, and publish eligibility
- [x] 8.2 Add API tests for study-event idempotency, duplicate handling, and out-of-order processing
- [x] 8.3 Run staged rollout checklist (feature flags, health/readiness checks, rollback drill) before broad enablement
