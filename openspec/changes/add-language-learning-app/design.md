## Context

The project starts from a product and technical brief for a Flutter language learning app. There is no existing mobile or backend implementation in this workspace yet, so this change defines the initial architecture and requirements contract for the MVP.

The core learning interaction is intentionally narrow: a Vietnamese learner swipes down to receive the next vocabulary card. The card can be either a new word or a review word. The app must target a 3-new / 7-review ratio, store only the 1000 most recent words on device, sync learning events to the backend, and continue working when the backend is unavailable.

The backend is responsible for long-term storage and AI-generated vocabulary. LiteLLM is used as the AI abstraction so the implementation can change providers or models later without changing the rest of the system.

## Goals / Non-Goals

**Goals:**

- Deliver an MVP architecture for Flutter on Android and iOS.
- Support a local-first learning loop that does not block on backend availability.
- Keep mobile storage bounded to the 1000 most recent words.
- Sync append-only study events to backend with idempotency.
- Expose backend APIs for new-word feed, recent-word bootstrap, and study-event sync.
- Generate vocabulary content through LiteLLM and persist validated generated words.
- Keep the server data model compatible with future authentication and personalization.

**Non-Goals:**

- User registration, login, OAuth, or authenticated sessions.
- Payment, subscriptions, social learning, leaderboards, classroom flows, or full admin tooling.
- Speech recording, pronunciation scoring, or audio generation.
- Complex spaced repetition algorithms beyond a simple configurable review schedule.
- Multi-language content management beyond the initial Vietnamese learner use case, though schemas should not block it.

## Decisions

### Use local-first mobile repositories

Mobile writes learning state and study events to local storage first, then syncs in the background.

Rationale: the swipe interaction must remain responsive under weak network conditions. Local-first also prevents data loss when sync fails.

Alternatives considered:

- Backend-first card selection: simpler server logic, but makes the main learning loop fragile when the network is slow.
- Fully offline static packs: reliable offline, but prevents AI-driven freshness and future personalization.

### Use SQLite-compatible structured local storage

The mobile local data layer should use SQLite with Drift, or an equivalent structured local database if the implementation has a stronger reason.

Rationale: the app needs queryable word states, due review lookup, a sync queue, and deterministic pruning to 1000 words. A relational model fits this better than ad hoc key-value storage.

Alternatives considered:

- Hive/Isar: viable for simpler object persistence, but review queries and retention policy become more application-driven.
- In-memory cache only: insufficient for offline learning and app restarts.

### Enforce a 5-second timeout for backend new-word requests on mobile

When the selected next card is a new word, mobile calls the backend with a 5-second timeout. On failure, timeout, or offline state, it falls back to eligible local words.

Rationale: users should not wait indefinitely after swiping. The timeout is a product constraint and must be enforced where the user experience is controlled.

Alternatives considered:

- Backend-controlled timeout only: does not protect the mobile UI from network stalls.
- Immediate local-only response plus prefetch: faster, but delays introduction of backend-generated words unless a prefetch buffer is well maintained. This can be added later.

### Use append-only study events with idempotent sync

Each rating submission creates a `client_event_id` and is queued for sync. The backend accepts each event once and ignores duplicates by idempotency key.

Rationale: append-only events are easier to retry, audit, and merge when future authentication adds multiple devices.

Alternatives considered:

- Sync mutable word state only: simpler payloads, but conflict resolution and lost updates become harder.
- Server-only event creation: not compatible with offline learning.

### Keep mobile words capped by recency, not mastery

When local words exceed 1000, the app retains the 1000 most recent words by `last_seen_at` or `updated_at` and removes older local word records after preserving pending sync events.

Rationale: the explicit product requirement is "1000 most recent words". Recency is easy to explain, deterministic, and keeps the database bounded.

Alternatives considered:

- Keep hardest words: pedagogically attractive, but violates "most recent" semantics and requires more scoring logic.
- Keep all words: simpler initially, but violates storage constraints.

### Use backend REST APIs for the MVP

The backend exposes REST endpoints for word feed, recent-word bootstrap, and study-event sync.

Rationale: the interaction surface is small and resource-oriented. REST is sufficient and easy for Flutter clients to consume.

Alternatives considered:

- GraphQL: unnecessary flexibility for the MVP and adds schema/client complexity.
- Realtime streaming: not needed for swipe-driven card retrieval.

### Generate AI vocabulary through LiteLLM with structured validation

The backend calls LiteLLM for vocabulary generation, requires JSON-shaped output, validates required fields, deduplicates by normalized term and language, then persists accepted words.

Rationale: AI output quality must be controlled before it reaches users or the database. LiteLLM keeps model choice replaceable.

Alternatives considered:

- Store AI output without validation: faster to build but risks broken cards and unsafe content.
- Hand-authored word lists only: higher control, but does not satisfy the AI generation requirement.

### Prepare auth without implementing auth

Server records include `device_id` now and nullable `user_id` fields where future personalization will need them.

Rationale: this avoids a migration-heavy rewrite when login is added, while keeping the MVP unauthenticated.

Alternatives considered:

- Device-only schema: simplest now, but makes future account merging harder.
- Full auth now: outside MVP scope.

## Risks / Trade-offs

- AI generates inaccurate pronunciation or examples -> Validate schema, deduplicate, store generation source, and leave room for manual review or moderation.
- Backend response latency hurts the swipe flow -> Enforce the 5-second mobile timeout and use local fallback; later add prefetching if metrics show frequent waits.
- Local cache runs out of new words while offline -> Fall back to due review words and keep the learning loop available.
- The 3-new / 7-review ratio conflicts with available inventory -> Treat the ratio as a target and fallback to the available card type when one pool is empty.
- Pending sync events refer to pruned words -> Preserve event payloads in the sync queue before deleting old local word rows.
- Future multi-device auth creates conflicts -> Keep study events append-only and compute aggregate word state from events.
- REST payloads drift from mobile models -> Define shared DTO contracts and validate API responses in tests.

## Migration Plan

1. Scaffold the Flutter app and backend service.
2. Add local mobile schema and repositories.
3. Add backend database schema and REST API contracts.
4. Implement AI generation behind a service interface using LiteLLM.
5. Wire the mobile learning loop to local repositories and backend APIs.
6. Enable background sync and pruning after core learning flow works.
7. Add telemetry and failure metrics for fallback, timeout, and sync outcomes.

Rollback strategy for the MVP is feature-level: keep local learning usable if backend generation or sync endpoints are unavailable, and gate backend-dependent functionality behind repository fallback behavior.

## Open Questions

- Should MVP support only English target vocabulary, or should schemas expose target language selection immediately?
- Should users manually choose an initial difficulty level, or should MVP default to A1-B2 mixed content?
- Should generated content be moderated synchronously before serving or asynchronously after persistence?
- Should backend generation be demand-driven only, or should it pre-generate batches for latency control?
- Should local fallback for "new" cards use only never-seen words, or also weakly remembered words when inventory is low?
