# Speaking Foundation Phase 0-3 — Status

## Goal
Complete the phase 0-3 Speaking Foundation Definition of Done: 3-minute drill, dashboard prompt review, weekly summary API, and beta metrics instrumentation.

## Constraints & Preferences
- 10.113.213.9 is the local Z440/deploy host.
- Deploy on worker Z440 using `/home/beou/deployment/worker-z440/docker-compose.yml`.
- Mobile release APK targets `BACKEND_BASE_URL=https://expat8.x51.vn` via `--dart-define`.
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` required for builds.
- Android SDK compileSdk must be ≥36 (flutter_tts requirement).
- Audio must remain local-only on device; no raw audio, no file paths in backend payloads.
- Feature flag `SPEAKING_FOUNDATION_ENABLED` (default false) — compile-time `--dart-define` — gates speaking UI on mobile.
- Phase 0-3 = **first phase, timeline 0–3 months** (not phases 0, 1, 2, 3).
- Kotlin 2.1.10 mandatory (≤2.0.20 cannot parse Kotlin 2.2.0 metadata from flutter_tts 4.2.5).

## Progress
### Done
- **Android release APK rebuilt** (`app-release.apk`, 60.0MB).
- **OpenSpec change `complete-speaking-phase-0-3`** — 57 tasks; all done except manual QA (9.3–9.6).
- **`add-speaking-foundation`** — 9.3 (static migration verification passes), 9.9 (release notes written) done; remaining: 9.8 (smoke test, blocked — needs running stack).
- **`content-ingestion-v2-foundation`** — 8.1 (integration tests, 7 pass), 8.3 (rollout checklist) done. All tasks complete.
- **`article-llm-vocabulary-suggestions`** — 4.3 (manual smoke test) blocked; all other tasks complete.
- **Backend**: 165 pass, 2 skipped (live-Postgres), 0 fail (167 total tests after 7 new integration tests).
- **Flutter**: 152 pass, 0 fail.

### Bug fixes this session
- **`WordStore.reviewVocabularyItem`** (`backend/src/word_store.js`): Now syncs `wordSense.status` to `approved`/`rejected` when a review item is approved/rejected. Without this, published article vocabulary was filtered out for non-owners because `sense.status` stayed `pending_review`.
- **`article_ingest_integration.test.js`** (3 assertions): Fixed to use `vocab.items` instead of treating `getArticleVocabulary` result as a plain array. The store returns `{ article_id, items }`.

### Remaining Manual QA
- `complete-speaking-phase-0-3` 9.3–9.6: Device/emulator tests (drill, dashboard prompt approval, offline sync, permission denied).
- `add-speaking-foundation` 9.8: Smoke test signed study-event sync for mixed rating/speaking batches against a local or dev backend.
- `fix-swipe-exhausted` 5.1: Manual emulator test — 5 swipes → 5 unique words.
- `article-llm-vocabulary-suggestions` 4.3: Manual smoke test (accepted vocab article + rejected-only article).

### Blocked
- All remaining tasks require a running stack (live Postgres, live backend, device/emulator).

## Key Decisions
(same as before — see previous memory version for full list; unchanged)

## Critical Context
- **`getArticleVocabulary` return shape**: `{ article_id: string, items: [...] }` — NOT a plain array. Tests must check `vocab.items`.
- **`reviewVocabularyItem` now syncs sense.status**: When `status = 'approved'` → `sense.status = 'approved'`; otherwise `'rejected'`. This is required for published-article vocabulary filtering.
- **`content-ingestion-v2-foundation` rollout checklist**: `openspec/changes/content-ingestion-v2-foundation/rollout-checklist.md` — 6 stages + rollback drill + sign-off table.
- **`add-speaking-foundation` release notes**: `openspec/changes/add-speaking-foundation/release-notes.md` — feature flag, privacy behavior, known limitations, beta rollout order.
- **`SPEAKING_FOUNDATION_ENABLED` default is `false`**: `bool.fromEnvironment('SPEAKING_FOUNDATION_ENABLED')` — must pass `--dart-define=SPEAKING_FOUNDATION_ENABLED=true` to enable.

## Relevant Files
- `backend/src/word_store.js`: `reviewVocabularyItem` (syncs sense.status); `getArticleVocabulary` (returns `{ article_id, items }`).
- `backend/test/article_ingest_integration.test.js`: 7 integration tests; all pass.
- `openspec/changes/content-ingestion-v2-foundation/rollout-checklist.md`: 6-stage rollout checklist.
- `openspec/changes/add-speaking-foundation/release-notes.md`: Release notes + beta rollout doc for speaking foundation.
- `openspec/changes/content-ingestion-v2-foundation/tasks.md`: All tasks `[x]`.
- `openspec/changes/add-speaking-foundation/tasks.md`: 9.3, 9.9 now `[x]`; 9.8 remains `[ ]`.
- `openspec/changes/article-llm-vocabulary-suggestions/tasks.md`: 4.3 remains `[ ]` (manual smoke test).
- `openspec/changes/complete-speaking-phase-0-3/tasks.md`: 9.3–9.6 remain `[ ]` (manual QA).
