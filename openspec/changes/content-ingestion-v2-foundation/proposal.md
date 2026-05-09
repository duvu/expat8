## Why

The current learning flow is optimized for local seed and preloaded vocabulary, but it does not support ingesting real user/admin content and turning it into governed learning material. We need a v2 foundation now to align implementation with the offline-first architecture while moving source-of-truth and SRS correctness to backend event processing.

## What Changes

- Add a user article ingestion capability so authenticated mobile users can upload study content for processing.
- Add an admin content workflow capability for create, review, approve, and publish of extracted vocabulary.
- Add an asynchronous processing pipeline capability for extraction, normalization, enrichment, and validation.
- Add a learning card serving capability that uses stored vocabulary only (no LLM in request path) and prioritizes due review + controlled new cards.
- Add a backend study-event ingestion capability with idempotency and deterministic SRS state projection.
- Add a content-pack/version sync capability so mobile can download approved content incrementally.
- Modify mobile sync and backend word-feed behaviors to treat backend as source of truth while preserving offline-first UX.

## Capabilities

### New Capabilities
- `article-ingestion-api`: Authenticated ingestion/list/detail lifecycle for user-uploaded articles.
- `admin-content-review`: Admin article management, vocabulary review, approval, and publish workflow.
- `article-processing-pipeline`: Queue-driven extraction, deduplication, LLM enrichment, and quality validation.
- `learning-cards-api`: Card selection and serving from approved/processed vocabulary without runtime generation.
- `content-pack-versioning`: Versioned content-pack listing and download APIs for incremental sync.

### Modified Capabilities
- `study-events-api`: Enforce event idempotency contract and backend-owned SRS projection from accepted events.
- `backend-word-feed-sync`: Change feed selection policy to backend-governed due-review/new-card selection with fallback behavior.
- `mobile-local-cache-sync`: Align mobile sync behavior with backend source-of-truth while keeping offline outbox flow.

## Impact

- Backend: new API routes/modules for articles, admin workflows, processing worker, learning cards, and content packs.
- Data model: new schemas for articles, terms/senses, article-term links, processing jobs/runs, content packs, and stronger study-event constraints.
- Mobile: upload/sync surfaces, local entity expansion, and stricter event/outbox sync contract.
- Operations: worker deployment profile, queue + Redis/Postgres nonce/rate-limit support, and migration plan updates.
- Security: stronger role-based admin actions, audit logging, replay/rate-limit controls on new endpoints.
