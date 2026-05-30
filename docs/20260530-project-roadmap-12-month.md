# Expat8 12-Month Project Roadmap

This roadmap is the durable planning baseline from OpenSpec change `create-project-roadmap`. It sequences work by evidence and gates, not by feature availability alone.

## Status Overview

| Phase | State | Last updated |
|---|---|---|
| Phase 0 — Trust and Release Readiness | **Implementation complete** — all code/contract gates Closed; mobile device verification Pending | 2026-05-30 |
| Phase 1 — Cohesive Daily Speaking Loop | **Implementation complete** — all code gates Closed; device smoke test Pending | 2026-05-30 |
| Phase 2 — Content Depth and Operational Coverage | **Implementation complete** — code gates Closed; manual content/device verification Pending | 2026-05-30 |
| Phase 3 — Lightweight AI Feedback | Blocked on Phase 2 exit | — |
| Phase 4 — Assessment, Retention, Business Signals | Blocked on Phase 3 exit | — |

**Active OpenSpec changes:**

| Change | Phase | State |
|---|---|---|
| `phase-0-trust-and-release-readiness` | Phase 0 | 37/46 tasks — 9 blocked on device/stakeholder |
| `phase-1-cohesive-daily-speaking-loop` | Phase 1 | 41/43 tasks — 2 blocked on device |
| `phase-2-content-depth-and-operational-coverage` | Phase 2 | 19/23 tasks — code gates Closed; 4 manual verification gates pending |
| `memorization-passages` | Phase 2 | 71/75 tasks — 4 manual/worker E2E gates pending |
| `memorization-segment-ipa-translation` | Phase 2 | 50/50 tasks — complete |
| `add-video-shadowing` | Phase 2 | 21/24 tasks — 3 physical Android/manual video gates pending |

**Pending before Phase 1 is fully closed:**
1. Physical Android device smoke test for `SpeakingSummaryScreen` + exam screens (task 8.4-8.5 in `phase-1-cohesive-daily-speaking-loop`).
2. Physical Android device verification for exam auto-advance, exam results screen, certificate API client, and swipe prefetch/prune (tasks 1.1-1.7 in `phase-0-trust-and-release-readiness`).
3. Stakeholder review and OpenSpec archive for both phase changes.

## North Star

Increase **weekly confident English-speaking minutes** for Vietnamese learners.

Roadmap decisions should favor work that connects existing vocabulary, content, and practice surfaces into a repeatable learner loop:

1. Add or encounter vocabulary.
2. Learn and review through SRS.
3. Practice in sentence, passage, article, or video context.
4. Speak or shadow in a short low-pressure drill.
5. Review weekly summary and self-rating.
6. Receive the next practice recommendation.

## Planning Rules

- Phase gates are binding: dependent work is blocked, deferred, or explicitly accepted as risk when evidence is missing.
- Every learner-facing proposal must say how it supports the vocabulary-to-speaking loop or why it is a Phase 0 trust/correctness item.
- Every cross-surface change must verify each affected surface and the integration boundary between them.
- New roadmap priorities must include an evidence note: product roadmap, README/docs, API contract, OpenSpec inventory, backend investigation, mobile/dashboard investigation, operational constraint, or specialist review.
- Non-goals require evidence before reconsideration.

## Phase 0 — Trust and Release Readiness (0-1 month)

**Goal:** make releases, contracts, schema safety, and known app/dashboard flows trustworthy before expanding product scope.

### Required gates

| Gate | Evidence required | Owner surface | Status |
|---|---|---|---|
| Mobile device verification | Manual device results for exam auto-advance, exam results screen, certificate API client, and swipe prefetch/prune | Mobile | **Pending — requires physical device** |
| Canonical release path | Written decision reconciling GitHub releases, backend-hosted releases, Play Store distribution, and self-upgrade behavior | Mobile/backend/ops | **Closed — `docs/canonical-release-path.md` committed** |
| API contract parity | `contracts/api.md` audited against backend routes plus mobile/dashboard clients; drift items recorded | Backend/mobile/dashboard | **Closed — article endpoints, CORS PATCH, content-packs, admin speaking prompts added to contract** |
| Schema/migration parity | Fresh DB schema and numbered migrations checked for critical runtime objects, especially nonce replay storage | Backend/ops | **Closed — nonces table added to `schema.sql`; migration uses `CREATE TABLE IF NOT EXISTS`** |
| Replay protection health | Behavior defined when nonce storage is unavailable, including fail-safe or alerting expectation | Backend/security | **Closed — `PostgresNonceCache` throws `NonceStorageUnavailableError` on missing table; `appCredentialGuard` returns 503 for write methods** |
| Dashboard correctness | Body encoding, article visibility enum, and certificate URL risks triaged | Dashboard/backend | **Closed — double-encoding fixed in `articles/[id]`; `shared` removed from `articles/new`; certificate URL proxied via `/api/certificate/[id]`** |

### Canonical release/update path

Use a staged path for the next 12 months:

1. **Internal builds:** GitHub Releases remain the audit trail for APK artifacts and release notes.
2. **In-app/self-upgrade checks:** backend-hosted release metadata is the runtime source used by the mobile app for update discovery.
3. **Public distribution:** Play Store remains the future user-facing distribution path once release signing, staged rollout, and rollback expectations are settled.

Any OpenSpec work touching releases must state which stage it affects and how it is verified.

### Contract drift follow-up list

**Audit completed — May 2026.** All known drift items are now resolved in `contracts/api.md`:

- ✅ `POST /v1/articles`, `GET /v1/articles` — added to contract.
- ✅ `GET /v1/articles/:id`, `GET /v1/articles/:id/vocabulary`, `DELETE /v1/articles/:id` — were already in contract.
- ✅ `POST /v1/admin/speaking-prompts` — added to contract.
- ✅ `GET /v1/admin/speaking-prompts`, `PATCH /v1/admin/speaking-prompts/:id` — were already in contract.
- ✅ Admin log archive endpoints (`GET /v1/admin/log-archives`, `GET /v1/admin/log-archives/:id`, `GET /v1/admin/log-archives/:id/content`) — were already in contract.
- ✅ `/v1/content-packs` — added to contract as internal/bootstrap endpoint.
- ✅ CORS `Access-Control-Allow-Methods` — updated to include `PATCH` and `DELETE`.
- ✅ `POST /v1/learning/cards` `card_mode: "new"` constraint — already documented in contract.
- ✅ `PATCH /v1/admin/articles/:id` visibility enum — already documented with `shared` → 400.

Deferred (requires further investigation or device access):
- Admin log archive download endpoint naming (`/content` vs `/download`) — contract documents `/content`; verify dashboard link names align.

### Schema and replay-protection gate

**Gate closed — May 2026:**

- `nonces` table added to `backend/db/schema.sql` using `CREATE TABLE IF NOT EXISTS`.
- `backend/db/migrations/20260510_postgres_nonce_cache.sql` already uses `CREATE TABLE IF NOT EXISTS` — no conflict on fresh init.
- `PostgresNonceCache.use()` in `backend/src/app_credentials.js` now throws `NonceStorageUnavailableError` when PostgreSQL error code `42P01` (undefined_table) is returned.
- `appCredentialGuard` in `backend/src/app.js` catches `NonceStorageUnavailableError` and returns HTTP 503 `REPLAY_PROTECTION_UNAVAILABLE` for POST, PUT, PATCH, DELETE. GET and OPTIONS proceed normally.
- `npm run verify:migrations` requires `DATABASE_URL` (live DB). To verify on a live DB: set `DATABASE_URL` and run `cd backend && npm run verify:migrations`.

### Dashboard risk triage

**All three risks closed — May 2026:**

| Risk | Fix applied | Verification |
|---|---|---|
| Backend body encoding convention | `articles/[id]/page.tsx` `patchArticle` action changed from `body: JSON.stringify(patch)` to `body: patch` — `backendFetch` handles serialization | Dashboard build passes; lint clean |
| Article visibility enum | `shared` option removed from `articles/new/page.tsx` form; edit page `[id]` already had only `private`/`published` | Dashboard build passes |
| Certificate links | `users/[id]/page.tsx` certificate href changed from `/v1/exam/certificate/:id` (same-origin) to `/api/certificate/:id`; new proxy route `src/app/api/certificate/[id]/route.ts` fetches from backend | Dashboard build passes |

**Phase 0 exit gate:** release path verified, critical mobile flows device-tested, contract drift fixed or tracked, migration/security checks enforced, and dashboard correctness risks closed or accepted with owners.

## Phase 1 — Cohesive Daily Speaking Loop (1-3 months)

**Goal:** make one repeatable learner journey explicit across existing mobile screens and backend endpoints.

### Implementation status (as of 2026-05-30)

| Gate | Status | Evidence |
|---|---|---|
| `loop_completed` event type + `loop_completion_count` summary | **Closed** | `backend/src/word_store.js` `SPEAKING_EVENT_TYPES`, `postgres_word_store.js` SQL, `contracts/api.md` updated |
| Backend tests for new event type and summary field | **Closed** | 291 pass, 0 fail |
| Worker graceful shutdown (SIGTERM/SIGINT + 10s drain) | **Closed** | `backend/src/worker.js` shutdown handlers |
| Mobile `postLoopCompletedEvent()` in SpeakingRepository | **Closed** | `speaking_repository.dart` |
| Mobile weekly speaking summary screen (`SpeakingSummaryScreen`) | **Closed** | `speaking_summary_screen.dart` + offline fallback |
| Drill completion "See weekly summary" CTA | **Closed** | `speaking_drill_screen.dart` `_summary()` |
| Speaking stats menu item navigates to `SpeakingSummaryScreen` | **Closed** | `learning_screen.dart` |
| `mobile-ui-improvements` section 6 tasks (7.1-7.8) | **Closed** | All 8 items verified in code: History icon, ProficiencyLevelLabel placement, FilledButton, DropdownButtonFormField, exam results single action, InkWell on choice tile, certificate URL `expat8.x51.vn/exam/certificate/:id`, Open Settings button |
| Dashboard loop health card on ops page | **Closed** | `expat8-dashboard/src/app/ops/page.tsx`, `GET /v1/admin/speaking/weekly-health`, lint + build clean |
| Device smoke test | **Pending** | Requires physical Android device |

**Phase 1 exit gate:** a learner can complete one repeatable vocabulary-to-speaking loop and the system can measure weekly speaking minutes plus completion.

### Learner loop map

| Step | Mobile surfaces | Backend/API surfaces | Completion evidence |
|---|---|---|---|
| Vocabulary/content input | Learning, Submitted Words, Articles, Workplace Sentence, content packs | `/v1/learning/cards`, `/v1/user-submitted-words`, `/v1/articles`, `/v1/words/recent`, `/v1/workplace-sentences/recent`, `/v1/content-packs` | Learner receives practice material without duplicate-card regressions |
| SRS review | Learning session and offline queue | `/v1/study-events`, `/v1/study-events/sync`, `/v1/user-word-cache`, `/v1/proficiency` | Ratings sync and proficiency updates are visible after retry/offline recovery |
| Contextual practice | Articles, Memorization, Workplace Sentence, Shadowing | Article vocabulary routes, memorization passage/progress routes, shadowing video routes | Learner can move from a word to a sentence/passage/video practice item |
| Speaking/shadowing | Speaking Drill, Shadowing, local recording/playback | `/v1/speaking/prompts`, `/v1/speaking/summary`, shadowing entry/detail routes | Short 3-10 minute practice can be completed without AI dependency |
| Summary/recommendation | Weekly summary, next-practice CTA | `/v1/speaking/summary`, study/proficiency state | Weekly minutes, attempts, confidence, and next action are shown |

### Minimum metrics

- Weekly confident speaking minutes.
- Speaking/shadowing attempt count.
- Loop completion rate.
- Retry rate after failed/low-confidence practice.
- Confidence self-rating before or after drills.
- Offline sync delay and failed sync count for loop-critical events.

### Dashboard/admin visibility

Keep dashboard scope operational, not a broad analytics platform:

- Content items waiting for enrichment, segmentation, review, or publish.
- Failed article/memorization/shadowing jobs and retry actions.
- Speaking prompt review status and missing required prompt fields.
- Release availability and uploaded mobile log archives.
- Aggregate loop health: completion, failure, and freshness indicators.

**Phase 1 exit gate:** a learner can complete one repeatable vocabulary-to-speaking loop and the system can measure weekly speaking minutes plus completion.

## Phase 2 — Content Depth and Operational Coverage (3-6 months)

**Goal:** finish content/practice inputs only after Phase 0 trust and Phase 1 loop evidence exist.

### Active work sequencing

| Active change | Roadmap phase | Why | Gate before release |
|---|---|---|---|
| `fix-build-release-consistency` | Phase 0 | Release trust prerequisite | ✅ Artifacts ready — device verification pending |
| `mobile-github-releases` | Phase 0 | Internal artifact distribution | ✅ Artifacts ready — device verification pending |
| `mobile-self-upgrade` | Phase 0 | User update discovery | ✅ Artifacts ready — device verification pending |
| `fix-shadowing-library-load-error` | Phase 0 | Existing feature correctness | ✅ Artifacts ready — device verification pending |
| `mobile-ui-improvements` | Phase 1 | Clarifies the daily learner loop | ✅ Complete — section 6 items verified in Phase 1 apply |
| `instant-add-word-learning` | Phase 1 | Shortens vocabulary input to SRS loop | ✅ Complete — 17/17 tasks |
| `memorization-passages` | Phase 2 | Adds contextual practice depth | 71/75 tasks — Docker worker, dashboard→worker→mobile, user passage, and exam integration manual gates pending |
| `memorization-segment-ipa-translation` | Phase 2 | Improves passage practice quality | ✅ Complete — 50/50 tasks |
| `add-video-shadowing` | Phase 2 | Adds low-pressure speaking bridge | 21/24 tasks — curated playback, learner import, and transcript-unavailable manual gates pending |
| `phase-2-content-depth-and-operational-coverage` | Phase 2 | Adds operational coverage and exit gate | 19/23 tasks — code gates Closed; 4 manual verification gates pending |

### Implementation status (as of 2026-05-30)

| Gate | Status | Evidence |
|---|---|---|
| Backend content pipeline health endpoint | **Closed** | `GET /v1/admin/content-pipeline/health`, in-memory and Postgres store methods |
| API contract for content pipeline health | **Closed** | `contracts/api.md` documents response shape and admin-only behavior |
| Backend tests for content pipeline health | **Closed** | `word_store.test.js` and `api.test.js` cover store shape and admin 403/200 behavior |
| Memorization contract tests | **Closed** | `api.test.js` covers missing session 401, valid session list/create, and `items` response shape |
| Shadowing catalog contract tests | **Closed** | `api.test.js` covers missing device 400, invalid bearer 401, and anonymous device catalog shape |
| Dashboard Content Pipeline card | **Closed** | `ops-data.ts` loader and `ops/page.tsx` card using signed `backendFetch` |
| Docker worker seed passage verification | **Pending** | Requires live Docker Compose worker run |
| Shadowing Android E2E | **Pending** | Requires physical Android device and transcript-backed YouTube samples |
| Memorization dashboard→worker→mobile E2E | **Pending** | Requires dashboard, worker, backend, and mobile surface run together |
| Exam passage-sourced question integration | **Pending** | Requires studied passage segments and exam pool verification |

### Worker/content track

- Article processing: backlog, failed enrichment, reprocess actions, publish status.
- Memorization segmentation/enrichment: status lifecycle, retry behavior, admin edit/split/merge coverage.
- Shadowing import: URL resolution, transcript availability, segment visibility, import retry/failure reason.
- Content quality: review status, stale queues, admin ownership of retry/publish decisions.

**Phase 2 exit gate:** practice inputs are reliable, visible to admins/operators, and covered by contract or integration tests.

## Phase 3 — Lightweight AI Feedback (6-9 months)

**Goal:** add constrained assistive AI only where learner activity already exists.

Allowed directions:

- Pronunciation hints or intelligibility labels after local speaking/shadowing practice.
- Phrase rewrites for learner-submitted or article-derived sentences.
- Summary suggestions and one next exercise based on existing study/speaking history.
- Content enrichment quality improvements for articles, memorization segments, and prompts.

Constraints:

- Audio processing must be asynchronous and privacy-aware.
- Local learning must not block when AI services fail.
- Cost, latency, and error metrics must be visible before expansion.

**Phase 3 exit gate:** feedback arrives within acceptable latency, learners retry after feedback, and cost/error metrics are visible.

## Phase 4 — Assessment, Retention, and Business Signals (9-12 months)

**Goal:** use retention evidence to decide whether assessment, monetization, or broader AI investments are justified.

- Strengthen exams/certificates only as progress proof for the core loop.
- Add retention views for speaking minutes, loop completion, confidence changes, and repeat usage.
- Consider paid-plan experiments only if speaking-loop retention and repeat practice are strong.

**Phase 4 exit gate:** business experiments are based on retention evidence, not feature availability alone.

## Cross-Surface Reliability Tracks

| Track | Scope | Required verification |
|---|---|---|
| Mobile | Endpoint payload conformance, ObjectBox/test environment setup, compile-time release config, device verification | `flutter test`; device smoke for changed flows; ObjectBox native library present for desktop tests |
| Backend | API contract drift, migrations, nonce replay protection, rate limiting, worker shutdown, route coverage | `npm test`; `npm run verify:migrations`; targeted route/contract tests; health readiness check |
| Dashboard | API-vs-DB read strategy, DB query compatibility, server-action tests, admin error states | `npm run lint`; `npm run build`; focused dashboard tests for changed workflows |
| Contracts | `contracts/api.md` as canonical API source | Contract diff checklist in every cross-surface proposal |
| Schema/migrations | Fresh schema plus migrations represent runtime requirements | Migration parity check before deploy |
| Workers/content | Article, memorization, shadowing processing, backlog visibility, retry behavior | Worker smoke, failed-job visibility, retry-path test |
| Observability/ops | Readiness, worker backlog, failed jobs, log archives, releases, dashboard connectivity | Local/production smoke checklist and alertable metrics |

## Quality and Observability Gates

### CI expectations

- Backend: `npm test`; run `node --test test/api.test.js` for API-focused changes; `npm run verify:migrations` for database-affecting changes.
- Mobile: `flutter test`; run focused controller/widget tests for changed flows; run ObjectBox codegen after entity changes.
- Dashboard: `npm run lint`; `npm run build`; add or run focused tests for server actions and admin workflows.
- Local stack: `docker compose up --build -d` smoke when integration behavior changes.

### Contract conformance tests

Add tests or scripted checks for:

- Mobile learning cards payload shape: no exclusion fields; `card_mode` only absent or `new`.
- Study event sync idempotency and auth/session behavior.
- Exam start/submit/results/certificate flow.
- Dashboard article create/update/reprocess/publish action payloads.
- Dashboard log archive and certificate link construction.
- Admin speaking prompt review workflow.

### Operational health checks

- Backend `/health` and `/health/ready`.
- Worker process running and backlog size not stale.
- Failed article/memorization/shadowing jobs visible with retry paths.
- Mobile log archive upload/list/download path works.
- Latest release metadata and download path resolve for supported platforms.
- Dashboard can reach backend and expected PostgreSQL schema.

### Phase-exit review criteria

Before a future OpenSpec change is marked complete, it must record:

- Roadmap phase and loop step, if any.
- Affected surfaces.
- Commands or manual checks run for each surface.
- Contract/schema/migration impact.
- Device or browser/API verification evidence for user-visible behavior.
- Known residual risks or explicit acceptance.

## Non-Goals for the Next 12 Months

These proposals are deferred unless new evidence justifies changing the roadmap:

| Non-goal | Evidence required to reconsider |
|---|---|
| Full open-ended real-time AI conversation tutor | Strong weekly speaking retention, privacy/cost controls, and reliable async feedback metrics |
| Social/community features | Repeat usage and moderation capacity evidence |
| Marketplace/creator ecosystem | Content quality pipeline, admin operations, and demand evidence |
| Large analytics/CMS platform | Proven dashboard operational gaps that cannot be solved by focused admin visibility |
| Multi-language expansion beyond current supported scope | Stable English loop metrics and localization/test capacity |
| Complex monetization | Retention and business signals from Phase 4 |

## Review and Maintenance

- Current accepted baseline: `create-project-roadmap` remains the canonical change slug for this roadmap work.
- External product/engineering stakeholder review is still required before archiving the OpenSpec change.
- Refresh cadence: review this roadmap after every significant mobile/backend/dashboard release, after any Phase 0 gate fails, or when speaking-loop retention data changes materially.
- Future proposals should link this document and state their phase, gate evidence, and non-goal impact.

## Evidence Sources

- Product direction: [`20260509-expat8-product-roadmap-2026-2028.md`](20260509-expat8-product-roadmap-2026-2028.md).
- Speaking foundation: [`20260509-expat8-phase-0-3-speaking-foundation.md`](20260509-expat8-phase-0-3-speaking-foundation.md).
- Project overview and invariants: [`project-overview.md`](project-overview.md), [`architecture-guide.md`](architecture-guide.md), [`testing-guide.md`](testing-guide.md), [`deployment-guide.md`](deployment-guide.md).
- Canonical API contract: [`../contracts/api.md`](../contracts/api.md).
- OpenSpec planning source: `openspec/changes/create-project-roadmap/`.
- Investigation evidence: backend route inventory, mobile/dashboard implementation survey, active OpenSpec inventory, and Oracle roadmap risk review from the proposal phase.
