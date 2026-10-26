# Memory

> Chronological action log. Hooks and AI append to this file automatically.
> Old sessions are consolidated by the daemon weekly.

## Session: 2026-05-09 11:21

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-09 11:35

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 11:45 | Added compact repo instructions | AGENTS.md, .wolf/anatomy.md, .wolf/memory.md | Preserved repo-specific commands, constraints, and verification order | ~400 |
| 11:46 | Edited backend/src/word_store.js | 11→9 lines | ~48 |
| 11:46 | Edited backend/src/word_store.js | modified resolveEventKey() | ~93 |
| 11:47 | Edited backend/src/postgres_word_store.js | added 1 import(s) | ~47 |
| 11:47 | Edited backend/src/postgres_word_store.js | 11→9 lines | ~50 |
| 11:47 | Edited backend/src/postgres_word_store.js | — | ~0 |
| 11:47 | Edited backend/src/postgres_word_store.js | modified createArticle() | ~75 |
| 11:47 | Edited backend/src/postgres_word_store.js | modified createAdminArticle() | ~72 |
| 11:47 | Edited backend/src/postgres_word_store.js | modified insertArticle() | ~240 |
| 11:47 | Edited backend/src/postgres_word_store.js | modified listAdminArticles() | ~89 |
| 11:48 | Edited backend/src/postgres_word_store.js | modified listContentPacks() | ~115 |
| 11:48 | Edited backend/src/postgres_word_store.js | modified claimNextArticleProcessingJob() | ~253 |
| 11:48 | Edited backend/src/postgres_word_store.js | modified for() | ~788 |
| 11:48 | Edited backend/src/app.js | trim() → validateArticleBody() | ~59 |
| 11:48 | Edited backend/src/app.js | trim() → validateArticleBody() | ~60 |
| 11:48 | Edited backend/src/app.js | modified validateArticleBody() | ~206 |
| 11:53 | Edited backend/test/word_store.test.js | 6→7 lines | ~88 |
| 11:53 | Edited backend/test/word_store.test.js | 6→7 lines | ~44 |
| 12:00 | Edited backend/test/api.test.js | 3→3 lines | ~46 |
| 12:01 | simplify: extracted resolveEventKey/compareEventsForProjection to shared exports; removed syncStudyEvents redundant aliases; merged createArticle/createAdminArticle INSERT; collapsed listAdminArticles+listContentPacks to single queries; extracted validateArticleBody; fixed hasAdminAccess instanceof Set; fixed TOCTOU in claimNextArticleProcessingJob (SELECT FOR UPDATE SKIP LOCKED); collapsed persistArticleVocabulary term upsert to ON CONFLICT; fixed word_store+api tests for duplicates field | backend/src/app.js, postgres_word_store.js, word_store.js, test/api.test.js, test/word_store.test.js | 92/95 pass (was 86/92) | ~4000 |
| 12:02 | Session end: 18 writes across 5 files (word_store.js, postgres_word_store.js, app.js, word_store.test.js, api.test.js) | 12 reads | ~55255 tok |

## Session: 2026-05-09 12:02

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 12:08 | Created openspec/changes/missing-api-endpoints/proposal.md | — | ~630 |

## Session: 2026-05-09 12:09

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 12:09 | Created openspec/changes/missing-api-endpoints/design.md | — | ~1239 |
| 12:10 | Created openspec/changes/missing-api-endpoints/specs/user-profile/spec.md | — | ~229 |
| 12:10 | Created openspec/changes/missing-api-endpoints/specs/article-vocabulary/spec.md | — | ~502 |
| 12:10 | Created openspec/changes/missing-api-endpoints/specs/article-deletion/spec.md | — | ~364 |
| 12:10 | Created openspec/changes/missing-api-endpoints/specs/article-admin-update/spec.md | — | ~429 |
| 12:10 | Created openspec/changes/missing-api-endpoints/specs/backend-readiness-probe/spec.md | — | ~277 |
| 12:11 | Created openspec/changes/missing-api-endpoints/specs/study-events-api/spec.md | — | ~452 |
| 12:11 | Created openspec/changes/missing-api-endpoints/tasks.md | — | ~867 |
| 12:12 | Session end: 8 writes across 3 files (design.md, spec.md, tasks.md) | 1 reads | ~4669 tok |

## Session: 2026-05-09 12:41

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 13:09 | Edited backend/src/word_store.js | removed 13 lines | ~6 |
| 13:09 | Edited backend/src/postgres_word_store.js | removed 24 lines | ~8 |
| 13:09 | Edited backend/src/app.js | modified if() | ~160 |
| 13:09 | Edited backend/src/postgres_word_store.js | modified if() | ~119 |
| 13:09 | Edited backend/src/postgres_word_store.js | 4→7 lines | ~80 |
| 13:09 | Edited backend/src/postgres_word_store.js | 8→8 lines | ~111 |
| 13:12 | simplify: removed dead getMe() from both stores; collapsed PATCH visibility double-check; collapsed 2 fallback queries in getArticleVocabulary to 1; fixed updated_at written on deleted articles in claim/completeArticleProcessingJob | backend/src/app.js, postgres_word_store.js, word_store.js | 95/97 pass (0 fail) | ~1500 |
| 13:12 | Session end: 6 writes across 3 files (word_store.js, postgres_word_store.js, app.js) | 4 reads | ~27000 tok |
| 13:19 | Edited docs/architecture.md | reduced (-31 lines) | ~512 |
| 13:19 | Edited docs/architecture.md | 6→6 lines | ~82 |
| 13:19 | Edited docs/architecture.md | 9→11 lines | ~291 |
| 13:20 | Edited docs/architecture.md | reduced (-6 lines) | ~397 |
| 13:20 | Edited docs/architecture.md | 7→7 lines | ~36 |
| 13:20 | Session end: 11 writes across 4 files (word_store.js, postgres_word_store.js, app.js, architecture.md) | 4 reads | ~28412 tok |
| 13:38 | Created openspec/changes/mobile-local-first-card-selection/proposal.md | — | ~635 |
| 13:39 | Created openspec/changes/mobile-local-first-card-selection/.openspec.yaml | — | ~12 |
| 13:41 | Created openspec/changes/mobile-local-first-card-selection/design.md | — | ~1145 |
| 13:41 | Created openspec/changes/mobile-local-first-card-selection/specs/mobile-local-cache-sync/spec.md | — | ~690 |
| 13:42 | Created openspec/changes/mobile-local-first-card-selection/specs/mobile-learning-session/spec.md | — | ~581 |
| 13:42 | Created openspec/changes/mobile-local-first-card-selection/tasks.md | — | ~556 |
| 13:43 | Session end: 17 writes across 9 files (word_store.js, postgres_word_store.js, app.js, architecture.md, proposal.md) | 6 reads | ~32289 tok |
| 13:47 | Edited mobile/lib/src/data/word_repository.dart | modified if() | ~235 |
| 13:47 | Edited mobile/lib/src/data/word_repository.dart | inline fix | ~11 |
| 13:47 | Edited mobile/lib/src/config.dart | modified fromEnvironment() | ~450 |
| 13:47 | Edited openspec/changes/mobile-local-first-card-selection/tasks.md | 3→3 lines | ~150 |
| 13:48 | Edited mobile/lib/src/session/learning_session_controller.dart | modified if() | ~326 |
| 13:48 | Edited openspec/changes/mobile-local-first-card-selection/tasks.md | 3→3 lines | ~108 |
| 13:48 | Edited openspec/changes/mobile-local-first-card-selection/tasks.md | 2→2 lines | ~89 |
| 13:48 | Edited mobile/test/learning_session_controller_test.dart | added optional chaining | ~1400 |
| 13:49 | Edited openspec/changes/mobile-local-first-card-selection/tasks.md | 6→6 lines | ~174 |
| 13:49 | Session end: 26 writes across 13 files (word_store.js, postgres_word_store.js, app.js, architecture.md, proposal.md) | 11 reads | ~35439 tok |
| 13:53 | Edited openspec/specs/mobile-local-cache-sync/spec.md | expanded (+16 lines) | ~683 |
| 13:53 | Edited openspec/specs/mobile-learning-session/spec.md | expanded (+8 lines) | ~574 |
| 13:54 | Session end: 28 writes across 13 files (word_store.js, postgres_word_store.js, app.js, architecture.md, proposal.md) | 13 reads | ~37976 tok |

## Session: 2026-05-09 14:15

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 14:15 | Recorded host mapping for deploy ops | .wolf/cerebrum.md, .wolf/memory.md | `<INTERNAL_HOST>` treated as local machine in this workspace | ~120 |
| 15:24 | Created docs/20260509-swipe-right-to-left-new-word-invariant.md | — | ~1645 |
| 15:24 | Session end: 29 writes across 14 files (word_store.js, postgres_word_store.js, app.js, architecture.md, proposal.md) | 14 reads | ~39738 tok |
| 15:29 | Created openspec/changes/fix-swipe-right-to-left-new-word/proposal.md | — | ~379 |
| 15:29 | Created openspec/changes/fix-swipe-right-to-left-new-word/design.md | — | ~489 |
| 15:30 | Created openspec/changes/fix-swipe-right-to-left-new-word/specs/mobile-learning-session/spec.md | — | ~719 |
| 15:30 | Created openspec/changes/fix-swipe-right-to-left-new-word/tasks.md | — | ~137 |
| 15:30 | Session end: 33 writes across 14 files (word_store.js, postgres_word_store.js, app.js, architecture.md, proposal.md) | 14 reads | ~41585 tok |
| 15:32 | Edited mobile/lib/src/session/learning_session_controller.dart | 9→9 lines | ~90 |
| 15:32 | Edited openspec/changes/fix-swipe-right-to-left-new-word/tasks.md | inline fix | ~39 |
| 15:34 | Edited mobile/test/learning_session_controller_test.dart | added optional chaining | ~558 |
| 15:34 | Edited openspec/changes/fix-swipe-right-to-left-new-word/tasks.md | 3→3 lines | ~88 |
| 15:35 | Session end: 37 writes across 14 files (word_store.js, postgres_word_store.js, app.js, architecture.md, proposal.md) | 14 reads | ~48046 tok |

## Session: 2026-05-09 18:22

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-09 03:00

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-10 20:21

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-10 04:00

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-05-30 documentation

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 00:00 | Created comprehensive documentation set | README.md, docs/index.md, docs/project-overview.md, docs/developer-setup.md, docs/architecture-guide.md, docs/backend-guide.md, docs/mobile-guide.md, docs/dashboard-guide.md, docs/api-guide.md, docs/deployment-guide.md, docs/testing-guide.md, .wolf/anatomy.md, .wolf/memory.md | Added project overview, setup, architecture, backend, mobile, dashboard, API, deployment, testing, and root README docs index | ~4500 |
| 00:00 | Applied roadmap OpenSpec documentation tasks | docs/20260530-project-roadmap-12-month.md, docs/index.md, README.md, openspec/changes/create-project-roadmap/tasks.md, .wolf/anatomy.md, .wolf/memory.md | Created evidence-gated 12-month roadmap baseline, linked it, mapped active changes to phases, defined gates/tracks/metrics/non-goals, and marked 23/26 OpenSpec tasks complete | ~3000 |
| 09:17 | Created openspec/changes/phase-0-trust-and-release-readiness/proposal.md | — | ~1164 |
| 09:18 | Created openspec/changes/phase-0-trust-and-release-readiness/design.md | — | ~2136 |
| 09:19 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-release-path/spec.md | — | ~687 |
| 09:19 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-contract-parity/spec.md | — | ~586 |
| 09:20 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-schema-migration-parity/spec.md | — | ~474 |
| 09:20 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-replay-protection-health/spec.md | — | ~442 |
| 09:20 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-dashboard-correctness/spec.md | — | ~592 |
| 09:20 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/mobile-release-android/spec.md | — | ~715 |
| 09:20 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/mobile-exam-navigation/spec.md | — | ~618 |
| 09:21 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/mobile-word-prefetch/spec.md | — | ~813 |
| 09:21 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/learning-cards-api/spec.md | — | ~725 |
| 09:21 | Created openspec/changes/phase-0-trust-and-release-readiness/specs/admin-api-documentation/spec.md | — | ~970 |
| 09:24 | Created openspec/changes/phase-0-trust-and-release-readiness/tasks.md | — | ~1638 |
| 09:24 | Session end: 13 writes across 4 files (proposal.md, design.md, spec.md, tasks.md) | 130 reads | ~112380 tok |
| 09:25 | Session end: 13 writes across 4 files (proposal.md, design.md, spec.md, tasks.md) | 130 reads | ~112380 tok |
| 09:29 | Created docs/canonical-release-path.md | — | ~864 |
| 09:30 | Edited backend/db/schema.sql | expanded (+14 lines) | ~179 |
| 09:30 | Edited backend/src/app_credentials.js | added optional chaining | ~174 |
| 09:30 | Edited backend/src/app_credentials.js | modified constructor() | ~70 |
| 09:31 | Edited backend/src/app.js | inline fix | ~34 |
| 09:31 | Edited backend/src/app.js | added error handling | ~276 |
| 09:31 | Edited expat8-dashboard/src/app/articles/[id]/page.tsx | 4→4 lines | ~32 |
| 09:31 | Edited expat8-dashboard/src/app/articles/new/page.tsx | 5→4 lines | ~54 |
| 09:32 | Created expat8-dashboard/src/app/api/certificate/[id]/route.ts | — | ~128 |
| 09:32 | Edited expat8-dashboard/src/app/users/[id]/page.tsx | "/v1/exam/certificate/${e." → "/api/certificate/${e.cert" | ~33 |
| 09:34 | Edited contracts/api.md | inline fix | ~19 |
| 09:34 | Edited contracts/api.md | expanded (+72 lines) | ~362 |
| 09:35 | Edited contracts/api.md | expanded (+26 lines) | ~218 |
| 09:36 | Edited contracts/api.md | expanded (+39 lines) | ~238 |
| 09:37 | Created openspec/changes/phase-0-trust-and-release-readiness/tasks.md | — | ~1638 |
| 09:37 | Edited docs/20260530-project-roadmap-12-month.md | 8→8 lines | ~417 |
| 09:38 | Edited docs/20260530-project-roadmap-12-month.md | modified Deferred() | ~318 |
| 09:38 | Edited docs/20260530-project-roadmap-12-month.md | 8→9 lines | ~219 |
| 09:38 | Edited docs/20260530-project-roadmap-12-month.md | 7→9 lines | ~202 |
| 09:43 | Edited README.md | 3→5 lines | ~93 |
| 09:44 | Edited docs/index.md | 1→2 lines | ~81 |
| 09:44 | Edited openspec/changes/phase-0-trust-and-release-readiness/tasks.md | inline fix | ~30 |
| 09:44 | Edited openspec/changes/phase-0-trust-and-release-readiness/tasks.md | inline fix | ~30 |
| 09:44 | Edited openspec/changes/phase-0-trust-and-release-readiness/tasks.md | inline fix | ~30 |
| 09:44 | Edited openspec/changes/phase-0-trust-and-release-readiness/tasks.md | inline fix | ~30 |
| 09:44 | Edited openspec/changes/phase-0-trust-and-release-readiness/tasks.md | inline fix | ~30 |
| 09:44 | Edited openspec/changes/phase-0-trust-and-release-readiness/tasks.md | 2→2 lines | ~56 |
| 09:45 | Session end: 40 writes across 14 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 134 reads | ~132741 tok |
| 09:46 | Session end: 40 writes across 14 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 134 reads | ~132741 tok |
| 10:11 | Session end: 40 writes across 14 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 134 reads | ~134133 tok |
| 10:22 | Session end: 40 writes across 14 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 135 reads | ~134133 tok |
| 10:24 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/proposal.md | — | ~930 |
| 10:25 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/design.md | — | ~1679 |
| 10:25 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/mobile-weekly-speaking-summary/spec.md | — | ~388 |
| 10:25 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/learner-loop-completion-signal/spec.md | — | ~467 |
| 10:25 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/worker-graceful-shutdown/spec.md | — | ~246 |
| 10:25 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/dashboard-loop-health/spec.md | — | ~341 |
| 10:26 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/mobile-speaking-drill/spec.md | — | ~358 |
| 10:26 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/speaking-study-events/spec.md | — | ~318 |
| 10:26 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/mobile-speaking-session/spec.md | — | ~222 |
| 10:32 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/tasks.md | — | ~1844 |
| 10:32 | Session end: 50 writes across 14 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 135 reads | ~141410 tok |
| 10:37 | Session end: 50 writes across 14 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 135 reads | ~141410 tok |
| 10:41 | Edited backend/src/word_store.js | 10→11 lines | ~85 |
| 10:41 | Edited backend/src/word_store.js | added 3 condition(s) | ~329 |
| 10:41 | Edited backend/src/word_store.js | modified if() | ~21 |
| 10:46 | Edited backend/src/word_store.js | 6→7 lines | ~69 |
| 10:46 | Edited backend/src/word_store.js | added 1 condition(s) | ~457 |
| 10:47 | Edited backend/src/postgres_word_store.js | modified FILTER() | ~523 |
| 10:47 | Edited backend/src/postgres_word_store.js | 15→16 lines | ~196 |
| 10:48 | Edited contracts/api.md | 8→11 lines | ~119 |
| 10:48 | Edited contracts/api.md | 6→7 lines | ~53 |
| 10:48 | Edited contracts/api.md | 4→5 lines | ~98 |
| 10:49 | Edited backend/test/api.test.js | expanded (+100 lines) | ~1065 |
| 10:50 | Edited backend/test/word_store.test.js | added 1 condition(s) | ~361 |
| 10:51 | Edited backend/src/worker.js | added 3 condition(s) | ~420 |
| 10:52 | Edited mobile/lib/src/speaking/speaking_repository.dart | 10→11 lines | ~146 |
| 10:52 | Edited mobile/lib/src/speaking/speaking_repository.dart | modified onDrillCompleted() | ~290 |
| 10:53 | Edited mobile/lib/src/api/models/speaking_models.dart | modified fromJson() | ~312 |
| 10:55 | Edited mobile/lib/src/speaking/speaking_repository.dart | added 1 import(s) | ~101 |
| 10:55 | Edited mobile/lib/src/speaking/speaking_repository.dart | modified SpeakingRepository() | ~154 |
| 10:55 | Edited mobile/lib/src/speaking/speaking_repository.dart | added error handling | ~299 |
| 10:55 | Edited mobile/lib/main.dart | 5→6 lines | ~46 |
| 10:56 | Created mobile/lib/src/speaking/speaking_summary_screen.dart | — | ~1466 |
| 10:56 | Edited mobile/lib/src/speaking/speaking_drill_screen.dart | added 1 import(s) | ~76 |
| 10:57 | Edited mobile/lib/src/speaking/speaking_drill_screen.dart | modified initState() | ~380 |
| 10:57 | Edited mobile/lib/src/speaking/speaking_drill_screen.dart | modified _summary() | ~493 |
| 10:57 | Edited mobile/lib/src/speaking/speaking_drill_screen.dart | 8→7 lines | ~67 |
| 10:57 | Edited mobile/lib/src/speaking/speaking_drill_screen.dart | 13→12 lines | ~118 |
| 10:58 | Edited mobile/lib/src/ui/learning_screen.dart | added 1 import(s) | ~39 |
| 10:58 | Edited mobile/lib/src/ui/learning_screen.dart | expanded (+6 lines) | ~163 |
| 10:59 | Edited mobile/lib/src/speaking/speaking_repository.dart | 12→11 lines | ~89 |
| 11:03 | Edited mobile/lib/src/ui/learning_screen.dart | removed 26 lines | ~17 |
| 11:03 | Edited mobile/lib/src/ui/learning_screen.dart | removed 78 lines | ~14 |
| 11:05 | Edited mobile/lib/src/ui/learning_screen.dart | 5→4 lines | ~34 |
| 11:08 | Created openspec/changes/phase-1-cohesive-daily-speaking-loop/tasks.md | — | ~1844 |
| 11:11 | Edited mobile/test/speaking_test.dart | modified for() | ~754 |
| 11:15 | Edited backend/src/word_store.js | added optional chaining | ~312 |
| 11:15 | Edited backend/src/word_store.js | 2→2 lines | ~56 |
| 11:16 | Edited backend/src/postgres_word_store.js | added optional chaining | ~388 |
| 11:16 | Edited backend/src/postgres_word_store.js | modified getSpeakingLoopHealthSummary() | ~33 |
| 11:16 | Edited backend/src/routes/admin.js | expanded (+9 lines) | ~103 |
| 11:16 | Edited expat8-dashboard/src/lib/ops-data.ts | expanded (+8 lines) | ~71 |
| 11:17 | Edited expat8-dashboard/src/lib/ops-data.ts | 7→9 lines | ~67 |
| 11:17 | Edited expat8-dashboard/src/lib/ops-data.ts | modified loadOpsOverview() | ~174 |
| 11:17 | Edited expat8-dashboard/src/lib/ops-data.ts | added error handling | ~195 |
| 11:18 | Edited expat8-dashboard/src/app/ops/page.tsx | CSS: isoDate, marginTop | ~1845 |
| 11:19 | Edited contracts/api.md | expanded (+27 lines) | ~271 |
| 11:20 | Edited openspec/changes/phase-1-cohesive-daily-speaking-loop/tasks.md | 7→7 lines | ~224 |
| 11:21 | Edited docs/20260530-project-roadmap-12-month.md | expanded (+17 lines) | ~424 |
| 11:21 | Edited openspec/changes/phase-1-cohesive-daily-speaking-loop/tasks.md | 4→4 lines | ~86 |
| 11:22 | Session end: 98 writes across 28 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 146 reads | ~242109 tok |
| 12:45 | Edited mobile/lib/src/exam/exam_certificate_screen.dart | "https://expat8.x51.vn/v1/" → "https://expat8.x51.vn/exa" | ~20 |
| 12:46 | Edited openspec/changes/phase-1-cohesive-daily-speaking-loop/tasks.md | 16→16 lines | ~440 |
| 12:47 | Edited docs/20260530-project-roadmap-12-month.md | expanded (+25 lines) | ~480 |
| 12:47 | Edited docs/20260530-project-roadmap-12-month.md | 9→9 lines | ~307 |
| 12:48 | Edited docs/20260530-project-roadmap-12-month.md | inline fix | ~84 |
| 12:49 | Session end: 103 writes across 29 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 147 reads | ~244334 tok |
| 12:57 | Created docs/COMMIT_REPORT_20260530_125603.md | — | ~2895 |
| 12:58 | Session end: 104 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 147 reads | ~247436 tok |
| 13:34 | Session end: 104 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 147 reads | ~247436 tok |
| 13:39 | Created openspec/changes/phase-2-content-depth-and-operational-coverage/proposal.md | — | ~858 |
| 13:41 | Created openspec/changes/phase-2-content-depth-and-operational-coverage/design.md | — | ~1076 |
| 13:42 | Created openspec/changes/phase-2-content-depth-and-operational-coverage/specs/content-pipeline-observability/spec.md | — | ~404 |
| 13:43 | Created openspec/changes/phase-2-content-depth-and-operational-coverage/specs/phase-2-exit-gate/spec.md | — | ~423 |
| 13:45 | Created openspec/changes/phase-2-content-depth-and-operational-coverage/tasks.md | — | ~1175 |
| 13:46 | Session end: 109 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 147 reads | ~251653 tok |
| 14:11 | Session end: 109 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~264393 tok |
| 16:35 | Session end: 109 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~264393 tok |
| 16:35 | Session end: 109 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~264393 tok |
| 16:35 | Session end: 109 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~264393 tok |
| 16:35 | Session end: 109 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~264393 tok |
| 16:35 | Session end: 109 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~264393 tok |
| 17:05 | Created openspec/changes/phase-3-lightweight-ai-feedback/proposal.md | — | ~1024 |
| 17:06 | Created openspec/changes/phase-3-lightweight-ai-feedback/design.md | — | ~1771 |
| 17:07 | Created openspec/changes/phase-3-lightweight-ai-feedback/specs/drill-feedback-jobs/spec.md | — | ~703 |
| 17:07 | Created openspec/changes/phase-3-lightweight-ai-feedback/specs/next-practice-recommendation/spec.md | — | ~595 |
| 17:07 | Created openspec/changes/phase-3-lightweight-ai-feedback/specs/content-pipeline-observability/spec.md | — | ~419 |
| 17:08 | Created openspec/changes/phase-3-lightweight-ai-feedback/specs/speaking-study-events/spec.md | — | ~307 |
| 17:09 | Created openspec/changes/phase-3-lightweight-ai-feedback/tasks.md | — | ~3020 |
| 17:11 | Session end: 116 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~272791 tok |
| 17:12 | Session end: 116 writes across 30 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 152 reads | ~272791 tok |
| 17:27 | Created docs/COMMIT_REPORT_20260530_172604.md | — | ~1966 |
| 13:58 | Session end: 117 writes across 31 files (proposal.md, design.md, spec.md, tasks.md, canonical-release-path.md) | 162 reads | ~277976 tok |

## Session: 2026-09-28 13:40

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 13:44 | Created docs/20260928-system-review-and-proposals.md | — | ~5057 |
| 13:45 | System review + proposals doc; backend 4 fail (crypto.promises.scrypt), mobile 18 fail on Flutter 3.47.5 | docs/20260928-system-review-and-proposals.md, docs/index.md | written | ~60k |
| 13:46 | Session end: 1 writes across 1 files (20260928-system-review-and-proposals.md) | 0 reads | ~5418 tok |
| 13:51 | Fixed P0 scrypt (promisify) + auth rate limit (IP + ip|identifier, prune, TRUST_PROXY); contract/.env/deploy docs | backend/src/{user_identity,rate_limit,app,config}.js, routes/auth.js, tests, contracts/api.md, docs/deployment-guide.md | 303 pass 0 fail | ~40k |
| 13:51 | Session end: 1 writes across 1 files (20260928-system-review-and-proposals.md) | 0 reads | ~5418 tok |
| 13:58 | Created backend/src/migrations.js | — | ~942 |
| 14:08 | Created .github/workflows/ci.yml | — | ~612 |
| 14:10 | Prod readiness: migration runner, loop_completed fix, sync error classification, mobile 246 green, CI, audits; 3 commits on prod-readiness/20260928 | backend, mobile, .github, dashboard | done | ~150k |
| 14:11 | Created docs/20260928-engagement-features-proposal.md | — | ~2708 |
| 14:11 | Engagement features proposal doc | docs/20260928-engagement-features-proposal.md | committed | ~8k |
| 14:11 | Session end: 4 writes across 4 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md) | 0 reads | ~9873 tok |
| 14:12 | Created docs/20260928-deploy-runbook-prod-readiness.md | — | ~564 |
| 14:16 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:16 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:16 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:16 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:16 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:17 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:17 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:17 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:17 | Session end: 5 writes across 5 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 0 reads | ~10478 tok |
| 14:21 | Created mobile/lib/src/games/sudoku/sudoku_difficulty.dart | — | ~215 |
| 14:21 | Created mobile/lib/src/games/sudoku/sudoku_generator.dart | — | ~1207 |
| 14:22 | Created mobile/lib/src/games/game_storage.dart | — | ~331 |
| 14:22 | Created mobile/lib/src/games/sudoku/sudoku_champion_store.dart | — | ~1681 |
| 14:22 | Created mobile/lib/src/games/sudoku/sudoku_game_controller.dart | — | ~2262 |
| 14:23 | Created mobile/lib/src/games/sudoku/sudoku_board_view.dart | — | ~1413 |
| 14:23 | Created mobile/lib/src/games/sudoku/sudoku_game_screen.dart | — | ~2906 |
| 14:23 | Created mobile/lib/src/games/sudoku/sudoku_champion_board_screen.dart | — | ~1178 |
| 14:24 | Created mobile/lib/src/games/sudoku/sudoku_home_screen.dart | — | ~1833 |
| 14:24 | Created mobile/lib/src/games/games_hub_screen.dart | — | ~407 |
| 14:30 | Sudoku offline game (5 levels, champion board) + offline learning test; 274 mobile tests pass | mobile/lib/src/games, mobile/test/games | committed on feature/sudoku-game | ~60k |
| 14:30 | Session end: 15 writes across 15 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 3 reads | ~24870 tok |
| 15:19 | Merged PR 20-24; fixed Android release build (Gradle 8.14.3/AGP 8.13/Kotlin 2.2.20, plugin compileSdk 36); offline-first mobile + backend claim; released v1.3.2 | mobile, backend, .github | done | ~200k |
| 15:19 | Session end: 15 writes across 15 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 9 reads | ~34896 tok |
| 15:55 | Session end: 15 writes across 15 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 9 reads | ~34896 tok |
| 16:00 | Created mobile/lib/src/games/sudoku/sudoku_board_game.dart | — | ~3768 |
| 16:06 | Created docs/games/20260928-word-blaster-game-design.md | — | ~2388 |
| 16:09 | Sudoku rewritten with Flame (PR #25); Word Blaster GDD + backlog epic #26, issues #27-#36 (PR #37 docs) | docs/games, mobile/lib/src/games | done | ~80k |
| 16:12 | Session end: 17 writes across 17 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 12 reads | ~41493 tok |
| 16:13 | Session end: 17 writes across 17 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 12 reads | ~41493 tok |
| 16:18 | Created mobile/lib/src/games/word_blaster/question_generator.dart | — | ~2292 |
| 16:20 | Created mobile/lib/src/games/word_blaster/word_blaster_session.dart | — | ~4029 |
| 16:24 | Created mobile/lib/src/games/word_blaster/game/word_blaster_game.dart | — | ~7360 |
| 16:25 | Created mobile/lib/src/games/word_blaster/word_blaster_stats.dart | — | ~1563 |
| 16:26 | Created mobile/lib/src/games/word_blaster/ui/word_blaster_home_screen.dart | — | ~2641 |
| 16:27 | Created mobile/lib/src/games/word_blaster/ui/word_blaster_play_screen.dart | — | ~4935 |
| 16:27 | Created mobile/lib/src/games/word_blaster/ui/word_blaster_recap_screen.dart | — | ~3139 |
| 16:34 | Created mobile/lib/src/games/word_blaster/ui/word_blaster_board_screen.dart | — | ~2415 |
| 19:02 | Word Blaster game implemented & merged (PR #39); issues #27-33,#35 closed; #34/#36 need device | mobile/lib/src/games, backend games, dashboard ops | done | ~300k |
| 19:03 | Session end: 25 writes across 25 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 16 reads | ~71895 tok |
| 19:39 | Session end: 25 writes across 25 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 16 reads | ~71895 tok |
| 19:40 | Session end: 25 writes across 25 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 16 reads | ~71895 tok |
| 19:50 | Session end: 25 writes across 25 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 16 reads | ~71895 tok |
| 08:00 | UI simplification (theme, learning screen action bar, drawer groups, copy) merged PR #42 | mobile/lib/src/ui, theme, widgets | done | ~120k |
| 08:00 | Session end: 25 writes across 25 files (20260928-system-review-and-proposals.md, migrations.js, ci.yml, 20260928-engagement-features-proposal.md, 20260928-deploy-runbook-prod-readiness.md) | 23 reads | ~71895 tok |

## Session: 2026-09-29 08:24

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 08:36 | UI pass on remaining screens (PR #43), bump 1.3.4+8 (PR #44), tag v1.3.4 released APK/AAB | mobile/lib/src/{ui,exam,shadowing,widgets} | done | ~40k |
| 08:47 | Created scripts/admin-request.mjs | — | ~939 |
| 08:49 | Created backend/db/ops/delete_user.sql | — | ~1591 |
| 08:50 | Created scripts/ops-check.mjs | — | ~1225 |
| 08:52 | Created scripts/ops/backup.sh | — | ~583 |
| 08:54 | Created docs/ops/README.md | — | ~1430 |
| 08:55 | Created docs/ops/deploy.md | — | ~1873 |
| 08:56 | Created docs/ops/mobile-release.md | — | ~1344 |
| 08:56 | Created docs/ops/backup-restore.md | — | ~1600 |
| 08:56 | Edited docs/ops/backup-restore.md | inline fix | ~59 |
| 08:57 | Created docs/ops/monitoring.md | — | ~1748 |
| 08:58 | Created docs/ops/troubleshooting.md | — | ~2511 |
| 08:59 | Created docs/ops/secrets.md | — | ~1946 |
| 09:00 | Created docs/ops/maintenance.md | — | ~1816 |
| 09:01 | Edited docs/ops/maintenance.md | 1→3 lines | ~87 |
| 09:02 | Created docs/index.md | — | ~1162 |
| 09:04 | Ops docs suite docs/ops (8 pages) + ops-check/admin-request/backup.sh/delete_user.sql, archived 33 docs (PR #45) | docs/ops, scripts, backend/db/ops | merged; tools verified on temp PG16 | ~120k |
| 09:04 | Session end: 15 writes across 13 files (admin-request.mjs, delete_user.sql, ops-check.mjs, backup.sh, README.md) | 3 reads | ~23349 tok |

## Session: 2026-09-29 10:05

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 10:30 | VPS 10.113.213.1: RAM cleanup (fail2ban restart, disable multipathd/fwupd/udisks2/ModemManager, journald 200M cap, docker prune), rabbitmq -> 3.13.7 no mgmt, deployed omniroute 3.8.50 in server2 compose (VPN-only :20128, mem_limit 512m) | remote:/root/deployment/server2/docker-compose.yml | ok, healthy | ~40k |
| 10:30 | Created ../../.claude/projects/-home-beou-IdeaProjects-expat8/memory/vps-server2-layout.md | — | ~287 |
| 10:31 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 10:39 | VPS 10.113.213.1: caddy omni.x51.vn block, +2G /swapfile2, oom_score_adj priorities (VPN core -900, caddy -800, omniroute -500), omniroute mem 640m/memswap 2g; fixed stale caddy bind-mount + invalid ws://mq upstream in host Caddyfile | remote server2 compose+Caddyfile | ok | ~30k |
| 10:39 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 10:44 | VPS 10.113.213.1: removed lite.x51.vn caddy block, OOM tiers (VPN core+caddy -900, omni -800), earlyoom w/ avoid/prefer, kernel.panic=10, disk/log cleanup, dropped unused rabbitmq_* volume decls | remote server2 | ok | ~20k |
| 10:44 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 10:45 | VPS 10.113.213.1: deleted /root/build, server2/litellm, server2/github-copilot-svcs (user request) | remote | ok, disk 7.7G free | ~2k |
| 10:45 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 10:46 | VPS 10.113.213.1: committed server2 changes a3e6f67 in /root/deployment (not pushed) | remote git | ok | ~3k |
| 10:46 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 10:48 | VPS 10.113.213.1: rebased server2 commit onto origin (worker-z440 change), pushed ef81952 to x51vn/deployment master | remote git | ok | ~2k |
| 10:48 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 11:27 | VPS 10.113.213.1: deleted /root/litellm_db_backup_20260513.sql.gz (user request) | remote | ok | ~1k |
| 11:27 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 11:44 | VPS omniroute: changed admin password via PATCH /api/settings (reset-password.mjs broken in image: missing bcryptjs) | remote | ok | ~5k |
| 11:44 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 12:03 | VPS: restored rabbitmq:3.13.7-management + :15672 (OpenStock health check needs mgmt API); committed locally on server | remote | ok | ~5k |
| 12:03 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |
| 12:04 | VPS: pushed f77b25c (rabbitmq mgmt restore) to x51vn/deployment | remote git | ok | ~1k |
| 12:04 | Session end: 1 writes across 1 files (vps-server2-layout.md) | 1 reads | ~1293 tok |

## Session: 2026-09-29 13:10

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 13:14 | OmniRoute review: added LITELLM_TIMEOUT_MS (AbortSignal) + fence-tolerant JSON parse in passage pipelines; found omniroute has no providers, Z440 cfg points at dead :5003 | backend/src/litellm_client.js, passage_*_pipeline.js, config/worker/runtime, compose | tests 314 pass | ~20k |
| 13:27 | Configured worker-z440 (local copy) .env EXPAT8_LITELLM_* -> OmniRoute VPN :20128, model combo 'expat8'; compose adds LITELLM_TIMEOUT_MS. Live test: auth OK, upstream fails (no providers) | ~/deployment/worker-z440/.env, docker-compose.yml | pending provider+combo | ~8k |
| 13:36 | OmniRoute: added 8 free no-auth providers via /api/providers/free-onboarding (DB backup db_backups/pre-free-providers-20260929.sqlite). Only aihorde (aphrodite/DeepSeek-V4.1-Flash) answers but output capped ~20-70 tokens -> unusable for expat8 | VPS omniroute | no working LLM yet | ~15k |
| 13:44 | Codex OAuth connected in OmniRoute; created combo expat8 = cx/gpt-5.6-terra-low -> cx/gpt-5.6-luna-low; e2e tests OK (10 words 27s, 20 words 51s, passage json_object 6s, submitted 7s); worker-z440 VOCAB_GENERATION_BATCH_SIZE=20 | VPS omniroute, ~/deployment/worker-z440 | working | ~10k |
| 13:44 | Created ../../.claude/projects/-home-beou-IdeaProjects-expat8/memory/expat8-llm-omniroute.md | — | ~257 |
| 13:44 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 0 reads | ~276 tok |
| 13:52 | OmniRoute codex LB across 2 ChatGPT accounts: providerStrategies.codex=random (round-robin/least-used stuck on 1 account). 12 req -> 8/4 split | VPS omniroute settings | working | ~12k |
| 13:52 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 0 reads | ~276 tok |
| 14:23 | OmniRoute expat8 combo -> round-robin over 5 providers (cx terra-low, kiro haiku-4.5, antigravity gemini-3.7-flash-low, gh gpt-5.4-nano, gemini 3-flash-preview), concurrencyPerModel 2, stickiness off; global promptCacheAffinityEnabled=false + fallbackStrategy=random. Verified even split 2/2/2/2/2, 3x5 concurrent; 10/10 expat8 prompts valid. Backup db_backups/pre-expat8-lb-20260929.sqlite | VPS omniroute | working | ~40k |
| 14:23 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 0 reads | ~276 tok |

## Session: 2026-09-29 15:47

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|

## Session: 2026-10-25 10:52

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 11:17 | Restored expat8 prod: merged worker into backend (EMBEDDED_WORKER), z440 compose + Caddy server2 + OmniRoute key; cleaned test DBs | backend/src/{worker_runner,worker,server,config}.js, .gitignore | prod healthy, smoke pass | ~40000 |

## Session: 2026-10-25 11:59

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 14:45 | Level-aware cards, per-level scheduler+backoff, LlmRateLimiter, internet crawler, deployed 20261025.1438 | backend/src/* | prod gen 20/20 B2 words | ~60000 |
| 15:20 | Curated collector (20 + weekly), LLM circuit breaker, stale article job reclaim; deployed 20261025.1515 | backend/src/* | OmniRoute down (502) blocks processing | ~40000 |

## Session: 2026-10-26 20:51

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 20:58 | Edited ../../.claude/projects/-home-beou-IdeaProjects-expat8/memory/expat8-llm-omniroute.md | 1→3 lines | ~140 |
| 20:58 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 2 reads | ~150 tok |
| 21:02 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:04 | crawler articles invisible: crawler->createAdminArticle, list/get include published | content_crawler.js, *word_store.js, tests | tests 342 pass | ~4000 |
| 21:04 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:07 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:09 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:11 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:12 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:16 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:22 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 3 reads | ~150 tok |
| 21:55 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 7 reads | ~150 tok |
| 21:56 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 7 reads | ~150 tok |
| 22:01 | Session end: 1 writes across 1 files (expat8-llm-omniroute.md) | 7 reads | ~150 tok |
| 22:06 | Created mobile/lib/src/games/math/math_problem.dart | — | ~2959 |
| 22:12 | Created mobile/lib/src/games/math/math_skills.dart | — | ~1291 |
| 22:12 | Created mobile/lib/src/games/math/math_game_context.dart | — | ~583 |
| 22:13 | Created mobile/lib/src/games/math/math_round.dart | — | ~684 |
| 22:14 | Created mobile/lib/src/games/math/math_ui.dart | — | ~4541 |
| 22:14 | Created mobile/lib/src/games/math/math_screens.dart | — | ~3266 |
| 22:15 | Created mobile/test/games/math/math_core_test.dart | — | ~1755 |
| 22:16 | Created mobile/lib/src/games/math/number_blaster.dart | — | ~2764 |
| 22:18 | Created mobile/test/games/math/number_blaster_test.dart | — | ~1172 |
| 22:19 | Created mobile/lib/src/games/math/math_race.dart | — | ~3435 |
| 22:20 | Created mobile/test/games/math/math_race_test.dart | — | ~973 |
| 22:21 | Created mobile/lib/src/games/math/whack_a_number.dart | — | ~4024 |
| 22:21 | Created mobile/test/games/math/whack_a_number_test.dart | — | ~1008 |
| 22:22 | Created mobile/lib/src/games/math/number_tower.dart | — | ~4189 |
| 22:22 | Created mobile/test/games/math/number_tower_test.dart | — | ~1004 |
| 22:24 | Created mobile/lib/src/games/math/math_duel.dart | — | ~3360 |
| 22:24 | Created mobile/test/games/math/math_duel_test.dart | — | ~915 |
| 22:34 | Word Blaster jank fix (audio pools, notify throttle, Picture caching) + 5 math games (blaster, race, whack, tower, duel) + flaky test root-cause fix | games/**, word_repository.dart, tests | 381 tests pass, APK 1.4.0 | ~150k |
| 22:34 | Session end: 18 writes across 18 files (expat8-llm-omniroute.md, math_problem.dart, math_skills.dart, math_game_context.dart, math_round.dart) | 16 reads | ~48140 tok |
| 22:48 | Created mobile/tool/generate_stage_audio.py | — | ~3239 |
| 22:54 | Created mobile/lib/src/games/common/game_story.dart | — | ~2490 |
| 22:55 | Created mobile/lib/src/games/common/game_story_scene.dart | — | ~7695 |
| 23:03 | Edited mobile/lib/src/games/common/game_story_scene.dart | 2→3 lines | ~24 |
| 23:05 | Created mobile/test/games/game_story_test.dart | — | ~1128 |
| 23:08 | single instance (singleTask), UI-isolate offload (logs/prune/batches/JSON), game story chapters w/ tiered music+scenes+shots across 6 games, APK 1.5.0 | games/common/*, data/local_database.dart, api client, manifest | 386 tests pass | ~250k |
| 23:09 | Session end: 23 writes across 22 files (expat8-llm-omniroute.md, math_problem.dart, math_skills.dart, math_game_context.dart, math_round.dart) | 18 reads | ~66288 tok |
| 23:16 | Created mobile/lib/src/games/quiz/quiz_core.dart | — | ~378 |
| 23:16 | Created mobile/lib/src/games/quiz/quiz_skills.dart | — | ~1281 |
| 23:16 | Created mobile/lib/src/games/quiz/quiz_round.dart | — | ~680 |
| 23:19 | Created mobile/lib/src/games/english/english_bank.dart | — | ~4155 |
| 23:20 | Created mobile/lib/src/games/english/english_quiz.dart | — | ~1166 |
| 23:20 | Created mobile/lib/src/games/quiz/quiz_game_context.dart | — | ~1178 |
| 23:22 | Created mobile/lib/src/games/english/sentence_builder.dart | — | ~2891 |
| 23:27 | Created mobile/lib/src/games/math/math_secondary.dart | — | ~2903 |
| 23:31 | Created mobile/test/games/english_games_test.dart | — | ~2099 |
| 23:37 | Created mobile/lib/src/api/backend_api_client.dart | — | ~9162 |
| 23:38 | Created backend/src/domain/speaking.js | — | ~2422 |
| 23:39 | Created backend/src/domain/study_events.js | — | ~1511 |
| 23:39 | Created backend/src/domain/proficiency_progress.js | — | ~737 |
| 23:39 | Edited backend/src/domain/proficiency_progress.js | 9→4 lines | ~14 |
| 23:39 | Created backend/src/domain/learning_cards.js | — | ~995 |
| 23:39 | Created backend/src/domain/pagination.js | — | ~39 |
| 23:39 | Created backend/src/domain/vocabulary.js | — | ~1701 |
| 23:40 | Created backend/src/domain/articles.js | — | ~408 |
| 23:40 | Created backend/src/domain/submitted_words.js | — | ~363 |
| 23:40 | Created backend/src/domain/exam.js | — | ~1457 |
| 23:40 | Created backend/src/domain/memorization.js | — | ~452 |
| 23:40 | Edited backend/src/domain/memorization.js | 4→4 lines | ~56 |
| 23:40 | Created backend/src/domain/shadowing.js | — | ~242 |
| 23:40 | Edited backend/src/word_store.js | reduced (-10 lines) | ~61 |
| 23:41 | Edited backend/src/word_store.js | expanded (+37 lines) | ~501 |
| 23:41 | Edited backend/src/word_store.js | removed 25 lines | ~44 |
| 23:41 | Edited backend/src/word_store.js | level() → wordsInLanguage() | ~127 |
| 23:41 | Edited backend/src/word_store.js | 3→2 lines | ~32 |
| 23:41 | Edited backend/src/word_store.js | inline fix | ~16 |
| 23:41 | Created backend/src/domain/word_cache.js | — | ~96 |
| 23:41 | Edited backend/src/word_store.js | reduced (-24 lines) | ~348 |
| 23:41 | Edited backend/src/word_store.js | added 1 import(s) | ~34 |
| 23:41 | Edited backend/src/word_store.js | modified createUserSubmittedWord() | ~626 |
| 23:42 | Edited backend/src/word_store.js | modified insertWord() | ~132 |
| 23:42 | Edited backend/src/word_store.js | reduced (-12 lines) | ~53 |
| 23:42 | Edited backend/src/domain/articles.js | inline fix | ~32 |
| 23:48 | grade 6-9 Math+English games on a subject-agnostic quiz core; API client one transport (2431→1011); LocalDatabase split by domain; brand theme/backdrop/card redesign | mobile games/api/data/ui | 395 tests pass | ~300k |
| 23:48 | Edited mobile/lib/src/ui/vocabulary_card.dart | inline fix | ~16 |
| 23:52 | backend SOLID/DRY refactor: shared business rules extracted to src/domain/*.js (study-event routing, proficiency progression, SRS + learning-card mix, word/sense/submission/article records, exam, speaking, memorization, shadowing, pagination, word cache) and used by both stores | backend/src/domain/*, word_store.js, postgres_word_store.js | npm test 345 pass/8 skip; with TEST_DATABASE_URL serial 353/353 | ~60k |
| 23:52 | split store god classes: exam/games/memorization/shadowing/speaking methods moved to src/stores/{memory,postgres}/*.js and mixed in via stores/mixin.js; PG transaction helper in stores/postgres/transaction.js | backend/src/stores/* | word_store 3162->1382 lines, postgres_word_store 3639->2161 | ~40k |
| 23:52 | YAGNI removals: src/store_utils.js (moved), src/article_term_extractor.js (never imported), buildScaleLevelState + DEFAULT_PROFICIENCY_LEVEL, store countConsecutiveRatings/getLastRatingType, dead WordStore logger call, shadowed duplicate /v1/exam/certificate route in routes/exam.js, unused submitExamSession disclaimer param in PG | backend/src | tests green | ~5k |
| 23:53 | review/refactor: backend domain/+stores split (agent, verified 345 pass/lint), mobile learning_screen split, shared StudyCardFrame/LevelBadge, dashboard single pg pool; APK 1.6.0 | backend/src, mobile/lib/src/ui, expat8-dashboard/src/lib | all suites green | ~60k |
| 23:53 | Session end: 60 writes across 46 files (expat8-llm-omniroute.md, math_problem.dart, math_skills.dart, math_game_context.dart, math_round.dart) | 33 reads | ~172093 tok |
| 23:54 | Session end: 60 writes across 46 files (expat8-llm-omniroute.md, math_problem.dart, math_skills.dart, math_game_context.dart, math_round.dart) | 33 reads | ~172093 tok |

## Session: 2026-10-26 00:48

| Time | Action | File(s) | Outcome | ~Tokens |
|------|--------|---------|---------|--------|
| 04:55 | Edited backend/test/api.test.js | expanded (+11 lines) | ~200 |
| 04:59 | Created expat8-dashboard/src/lib/config.ts | — | ~242 |
| 04:59 | Created expat8-dashboard/src/lib/backend.ts | — | ~926 |
| 04:59 | Created expat8-dashboard/src/lib/ops-data.ts | — | ~1529 |
| 05:00 | Created expat8-dashboard/src/lib/db.ts | — | ~2387 |
| 05:00 | Edited mobile/lib/src/data/word_repository.dart | added optional chaining | ~148 |
| 05:01 | Created expat8-dashboard/src/lib/analytics.ts | — | ~6161 |
| 05:01 | Created backend/src/domain/srs.js | — | ~1008 |
| 05:01 | Edited backend/src/domain/srs.js | modified compareEvents() | ~100 |
| 05:01 | Edited backend/src/domain/srs.js | getTime() → occurredMs() | ~77 |
| 05:02 | Edited backend/src/domain/srs.js | modified replaySrsState() | ~39 |
| 05:02 | Edited backend/src/domain/srs.js | 1→2 lines | ~31 |
| 05:02 | Created backend/test/srs.test.js | — | ~752 |
| 05:03 | Created mobile/lib/src/engagement/engagement_logic.dart | — | ~1857 |
| 05:03 | Created mobile/lib/src/data/local_database_engagement.dart | — | ~340 |
| 05:03 | Edited mobile/lib/src/data/local_database.dart | 1→2 lines | ~21 |
| 05:03 | Created mobile/lib/src/engagement/engagement_repository.dart | — | ~734 |
| 05:04 | Created backend/src/domain/review_states.js | — | ~561 |
| 05:04 | Created mobile/lib/src/engagement/reminder_service.dart | — | ~1050 |
| 05:04 | Created mobile/lib/src/engagement/engagement_controller.dart | — | ~690 |
| 05:04 | Edited mobile/lib/src/engagement/engagement_controller.dart | modified catch() | ~59 |
| 05:04 | Created mobile/lib/src/engagement/engagement_panel.dart | — | ~1425 |
| 05:04 | Created backend/test/review_states.test.js | — | ~1322 |
| 05:04 | Edited backend/test/review_states.test.js | 4→2 lines | ~34 |
| 05:05 | Created mobile/lib/src/engagement/engagement_settings_sheet.dart | — | ~1313 |
| 05:05 | Edited backend/test/word_store.test.js | modified for() | ~386 |
| 05:06 | Created mobile/test/engagement_logic_test.dart | — | ~1801 |
| 05:07 | Created mobile/test/engagement_test.dart | — | ~2089 |
| 05:07 | Created mobile/test/learning_screen_engagement_test.dart | — | ~886 |
| 05:07 | Edited backend/test/postgres_integration.test.js | modified resetSchema() | ~818 |
| 05:09 | Learner engagement (streak, daily goal, due-soon, daily reminder) in mobile/lib/src/engagement + panel on LearningScreen, drawer item, main wiring, manifest/desugaring; 420 tests pass | mobile/lib/src/engagement/*, learning_screen.dart, learning_drawer.dart, main.dart, local_database_engagement.dart | done | ~60000 |
| 05:09 | Created mobile/lib/src/srs/srs_scheduler.dart | — | ~746 |
| 05:10 | Dashboard SOLID/DRY refactor + bug fixes (pipeline job statuses, log download proxy, exam cert link, speaking-prompt 'all' filter, toolbar-class filter forms, unchecked backend errors), standalone Docker (non-root, healthcheck), .env.example; lint/tsc/test(4/4)/build pass; all SQL validated on PGlite | expat8-dashboard/** | done | ~90000 |
| 05:23 | Created mobile/test/srs/family_sync_test.dart | — | ~1802 |
| 05:32 | Created mobile/lib/src/ui/article_reader.dart | — | ~1808 |
| 05:33 | Created mobile/test/article_reader_test.dart | — | ~994 |
| 05:34 | Created mobile/lib/src/review/review_exercise.dart | — | ~1443 |
| 05:35 | Created mobile/lib/src/ui/review_exercise_view.dart | — | ~2942 |
| 05:36 | Created mobile/test/review/review_exercise_test.dart | — | ~1504 |
| 05:50 | Fixed article list returning 1 item (queryLimit) and deployed backend 20261027.0456 | backend/src/routes/* | prod shows 50 articles | ~3k |
| 06:40 | Server-side SRS: domain/srs.js replay, review states API, many-misses downgrade, migration 20261027_srs_memory, rebuild:srs | backend/src/** | 352 pass + 3 PG integration | ~40k |
| 07:20 | Mobile SRS twin, owner-stamped events, schedule rebuild on account switch, review pull, upsert keeps schedule | mobile/lib/src/{srs,data} | 425 pass | ~40k |
| 07:40 | Dashboard refactor (agent) + SRS chart statuses; deployed expat8-dashboard VPN-only 10.113.213.9:18788 | expat8-dashboard, z440 compose | healthy, all nav 200 | ~10k |
| 08:10 | Article reader highlights vocab + Add to review; active-recall review exercises replace FitbCard | mobile/lib/src/{ui,review} | 425 pass, analyze clean | ~30k |
| 05:50 | Created mobile/test/learning_screen_review_test.dart | — | ~909 |
| 08:30 | Fixed schedule upgrade wiping signed-in history (claimUnownedEvents + rebuild keeps learningState/lastSeen); exercises disable swipes/action bar | mobile/lib/src/data, ui | 427 pass; APK 1.7.0+16 rebuilt | ~8k |
| 05:55 | Session end: 38 writes across 32 files (api.test.js, config.ts, backend.ts, ops-data.ts, db.ts) | 5 reads | ~81890 tok |
| 08:45 | Deployed backend 20261027.0558: migration srs_memory + rebuild:srs (276 states) | z440 | healthy | ~3k |
| 05:59 | Session end: 38 writes across 32 files (api.test.js, config.ts, backend.ts, ops-data.ts, db.ts) | 5 reads | ~81890 tok |
