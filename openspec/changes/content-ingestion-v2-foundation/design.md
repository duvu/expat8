## Context

Expat8 currently supports offline-first vocabulary learning with local cache and backend-assisted refill, but it does not support a governed pipeline from real content ingestion to reviewable/publishable vocabulary. The target architecture introduces user/admin article ingestion, asynchronous processing, and backend-owned event/SRS correctness while preserving mobile offline continuity.

Current constraints:
- Mobile must remain usable offline and should not block visible learning flow on network failures.
- Backend APIs must avoid LLM calls in latency-sensitive card serving paths.
- Existing study-event and word-feed specs already exist and must be evolved instead of replaced.
- Deployment currently centers on backend API service; worker and queue behavior must be introduced without destabilizing existing flows.

Stakeholders:
- Learners (mobile) need reliable first-card experience and progressive sync.
- Admin/reviewer users need quality control before publishing shared content.
- Backend operations need predictable scaling and failure isolation for processing.

## Goals / Non-Goals

**Goals:**
- Introduce end-to-end article ingestion and processing as a first-class source of vocabulary.
- Separate serving path (deterministic, low-latency) from enrichment path (async worker + LLM).
- Enforce study-event idempotency and backend-owned SRS projection semantics.
- Support versioned content distribution for mobile incremental sync.
- Keep existing offline-first UX intact with local outbox and local card-serving fallback.

**Non-Goals:**
- Replacing mobile local DB engine in this change.
- Implementing a full social/feed/classroom model.
- Running automatic web crawling or mass autonomous generation.
- Shipping advanced SRS algorithm tuning beyond deterministic event projection rules.

## Decisions

### Decision 1: Two-plane backend architecture (serving plane vs processing plane)
- Choice: Keep `/v1/learning/cards`, `/v1/study-events/sync`, and proficiency/content-pack reads in API serving plane; move extraction/enrichment into worker plane.
- Rationale: Preserves p95 latency and shields user-facing APIs from LLM/runtime variability.
- Alternative considered: Inline enrichment in API request path.
- Rejected because: Unbounded latency/cost spikes and poor resilience.

### Decision 2: Article lifecycle with explicit moderation states
- Choice: Standardize article states: `pending_processing` → `processing` → `pending_review|processed` → `published`.
- Rationale: Supports both private user ingestion (auto-processed) and admin-governed publication.
- Alternative considered: Single processed/unprocessed boolean.
- Rejected because: Insufficient control for admin review and recovery.

### Decision 3: Event log as SRS source of truth
- Choice: Backend accepts immutable study events (`event_id` idempotency key), projects SRS state deterministically, and returns accepted/duplicate/rejected detail.
- Rationale: Handles retries/out-of-order sync robustly and allows replay/rebuild if needed.
- Alternative considered: Trusting client-computed final SRS state.
- Rejected because: Drift risk, replay ambiguity, and weak auditability.

### Decision 4: Vocabulary data model with term/sense separation
- Choice: Keep `terms` and `word_senses` as separate entities with article-term link table.
- Rationale: Supports polysemy, deduplication, and context-specific examples without forcing one-term-one-meaning.
- Alternative considered: Single flat vocabulary table only.
- Rejected because: Difficult to model multiple senses and review decisions cleanly.

### Decision 5: Content-pack incremental sync contract
- Choice: Expose versioned `content-packs` listing and item download endpoints; mobile syncs by version watermark.
- Rationale: Efficient offline updates and safer rollouts than full re-fetch.
- Alternative considered: Re-download all vocabulary periodically.
- Rejected because: Wasteful bandwidth and unstable local user experience.

### Decision 6: Shared nonce/rate-limit backing store for multi-instance safety
- Choice: Prefer Redis `SET NX EX` for nonce and endpoint counters; allow PostgreSQL fallback where needed.
- Rationale: Replay defense and limits must remain correct under horizontal scaling.
- Alternative considered: In-memory process stores.
- Rejected because: Fails under multi-instance and restarts.

## Risks / Trade-offs

- [Processing backlog growth] → Mitigation: queue visibility metrics, retry caps, dead-letter queue, worker concurrency controls.
- [LLM enrichment quality variance] → Mitigation: strict output schema validation, confidence thresholds, admin review gates.
- [Schema migration complexity] → Mitigation: additive migrations first, dual-write/read where needed, staged rollout with backfill jobs.
- [Mobile sync drift while offline] → Mitigation: idempotent sync protocol, deterministic projection, explicit duplicate/reject reporting.
- [Operational overhead from extra services] → Mitigation: isolated worker deployment profile and readiness checks per service role.

## Migration Plan

1. Introduce additive database migrations for articles, processing, term/sense, content-pack, and stricter study-event indexes.
2. Deploy backend API changes with feature flags for new endpoints while keeping current learning flow intact.
3. Deploy processing worker and queue integration; enable processing for admin-only content first.
4. Enable mobile article upload and content-pack incremental sync behind config flags.
5. Enable user article ingestion and broaden publish workflow after validation.
6. Monitor metrics/error budgets; rollback by disabling feature flags and draining worker queue if needed.

Rollback strategy:
- API plane: disable new routes/flags while preserving existing card/study-event endpoints.
- Worker plane: stop worker deployment and pause queue consumption.
- Data safety: additive schema remains backward-compatible; no destructive down-migration in hot rollback.

## Open Questions

- Should private user-uploaded content skip admin review entirely or pass lightweight automated gating before user-visible learning?
- What is the default publication policy when an article has mixed-confidence extracted senses?
- Which queue implementation should be canonical for MVP (Redis-based queue vs Postgres job table) given current infra constraints?
- Do we need per-language extraction strategy configuration in MVP, or one shared baseline extractor with language-specific stopword sets?

## Admin Web Dashboard Exploration

The admin dashboard should be a browser surface for content editors and reviewers, not a second content system. It should orchestrate the existing backend article pipeline and expose the workflow state already persisted by the backend.

### Core flow

```text
Admin paste/import article
  -> POST /v1/admin/articles
  -> article row created with pending_processing
  -> processing job enqueued automatically
  -> worker extracts terms/phrases
  -> LLM enriches candidates
  -> backend persists article_terms + word_senses + review items
  -> GET /v1/admin/review/vocabulary?status=pending
  -> PATCH /v1/admin/vocabulary/:id
  -> POST /v1/admin/articles/:id/publish
```

### Recommended pages

| Page | Purpose | Backend shape |
| --- | --- | --- |
| Login | Acquire admin access | app credential headers + admin token |
| Articles | List and filter articles | `GET /v1/admin/articles` |
| New article | Paste raw text or import from URL | `POST /v1/admin/articles` |
| Article detail | Show article state and actions | list response + `PATCH`/reprocess/publish responses |
| Vocabulary review | Review extracted terms and phrases | `GET /v1/admin/review/vocabulary` |

### Article editor contract

The create form should only promise fields the backend already accepts:

- `title`
- `language`
- `raw_text`
- `source_url` optional
- `visibility`

If the UI shows `topic`, `target level`, or similar metadata, it should be treated as future-facing helper metadata until the API supports it.

### Vocabulary item contract

The dashboard should render the validated item shape, not raw LLM output. The practical display fields are:

- term or phrase
- explanation: `meaning_vi` plus optional `short_definition`
- usage: `example` and `example_vi`
- `part_of_speech`
- `ipa`
- `vietnamese_pronunciation`
- `difficulty`
- `topics`
- `quality_score` / confidence
- review `status`
- `review_note`

The backend validator currently expects required content, a valid difficulty, a topics array, and a language-appropriate pronunciation field. For non-Chinese items it requires IPA; for Chinese items it expects pinyin-like pronunciation.

### State model

```text
draft -> pending_processing -> processing -> pending_review -> published
                         \-> processing_failed
                         \-> dead_lettered
```

The dashboard should treat these as explicit states, not a single generic processing badge.

### Auth and transport

Current backend rules still require app credential headers on `/v1/*`, while admin routes additionally require `x-expat8-admin-token` or `x-admin-token`.

For a browser dashboard there are two viable shapes:

1. Direct browser client with CORS plus signed requests.
2. Small backend-for-frontend or reverse proxy that injects app credentials server-side.

The first matches the current contract and is the fastest path. The second is cleaner if we want to keep signing material out of the browser bundle.

### Important gaps

- There is no dedicated `GET /v1/admin/articles/:id` endpoint yet.
- There is no article-scoped admin vocabulary endpoint yet.
- The dashboard can start with the article list and the global pending-review queue, but drill-down likely wants new admin read endpoints later.
- The worker, not the dashboard, is responsible for calling the LLM.

### Practical recommendation

For MVP, a `web-admin/` Next.js app should cover:

- article composer
- article list/detail
- vocabulary review table
- publish controls

Keep it thin: orchestrate workflow and display state, but do not duplicate enrichment or review logic in the browser.
