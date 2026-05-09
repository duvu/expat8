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
| 14:15 | Recorded host mapping for deploy ops | .wolf/cerebrum.md, .wolf/memory.md | `10.113.213.9` treated as local machine in this workspace | ~120 |
