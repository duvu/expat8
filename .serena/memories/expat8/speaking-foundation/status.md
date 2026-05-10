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
- Feature flag `SPEAKING_FOUNDATION_ENABLED` (default true) gates speaking UI on mobile.
- Phase 0-3 = **first phase, timeline 0–3 months** (not phases 0, 1, 2, 3).
- Kotlin 2.1.10 mandatory (≤2.0.20 cannot parse Kotlin 2.2.0 metadata from flutter_tts 4.2.5).

## Progress
### Done
- **Android release APK rebuilt** (`app-release.apk`, 60.0MB).
- **OpenSpec change `complete-speaking-phase-0-3`** — 57 tasks; all done except manual QA (9.3–9.6).
- **Tasks 1.1–1.5 (DB/Migration)**: `speaking_prompts` table + indexes confirmed; migration `20260510_speaking_drill_completed.sql` created; seed file with 50 curated prompts created.
- **Tasks 2.1–2.5 (Backend Events)**: `speaking_drill_completed` added to `SPEAKING_EVENT_TYPES` (now 8 types); `normalizeSpeakingEvent` validates drill_completed fields; proficiency bypass confirmed; all tests passing.
- **Tasks 3.1–3.7 (Speaking Summary API)**: `getSpeakingSummary` + `buildSpeakingSummary` extended with `retry_rate`, `drill_sessions_completed`, `first_recording_at`; route wired; tests pass.
- **Tasks 4.1–4.5 (Admin/Mobile Prompts API)**: Admin CRUD confirmed existing; `GET /v1/speaking/prompts` mobile endpoint added; all 112 backend tests passing (2 skipped intentionally).
- **Group 5 (Mobile sync)**: `SpeakingPromptEntity`, `SpeakingPromptRepository` (getDrillCandidates/upsertAll/getByWordSenseId), `SpeakingPromptSyncService` created and wired in `main.dart`.
- **Group 6 (Drill UI)**: `SpeakingDrillScreen` fully implemented with progress indicator, listen/record/retry/rate phases, summary screen, empty state. Entry point added to `LearningDrawer`. Routing wired.
- **Group 7 (Drill events)**: All events wired — `onDrillPromptViewed`, `onDrillSamplePlayed`, `onDrillRetried`, `onDrillSelfRated`, `onDrillCompleted`.
- **Group 8 (Dashboard)**: Speaking prompts page exists at `/speaking-prompts`; nav link present on home page; approve/reject server actions wired.
- **Group 9 (QA)**: Backend 112/114 tests pass; mobile 133/133 tests pass; APK rebuilt (60.0MB); `contracts/api.md` updated with new endpoints and event types.
- **Bug fix**: `_rating` assignment in `_DrillPromptCardState._onRate` removed (field was previously declared but unused; orphaned assignment was a compile error).

### Remaining Manual QA (9.3–9.6)
- 9.3 Manual smoke test: start drill on device → record 5 sentences → see summary → verify events appear in backend logs
- 9.4 Manual test: dashboard → speaking prompts page → edit a prompt → approve → confirm approved prompt returned by `GET /v1/speaking/prompts`
- 9.5 Test offline drill: airplane mode → start drill → complete → reconnect → verify events sync
- 9.6 Test permission denied: revoke microphone permission → open drill → confirm no crash, graceful message shown

### Blocked
- (none)

## Key Decisions
- **`study_events` has no `event_type` column** — task 1.3 spec was wrong; composite analytics index placed on `speaking_events(device_id, event_type, occurred_at)` instead.
- **`word_sense_id` made nullable** in new migration; PostgreSQL `ALTER COLUMN DROP NOT NULL` used.
- **`SpeakingRating` enum kept with `easy/ok/hard` local storage values** for backwards compat; only the emitted backend event type name changes (via new `.eventType` extension).
- **`SpeakingDrillRating` is separate enum** from `SpeakingRating` — drill uses clear/hesitated/couldNotSay labels; vocab card keeps easy/ok/hard labels.
- **`fetchJson` already calls `signedFetchOptions` internally**: do NOT wrap options in `signedFetchOptions` before passing to `fetchJson` — double-signs and corrupts credentials.
- **App-cred guard fires before admin guard**: unauthenticated `/v1/*` requests get 400 (missing app credentials), not 403 (admin forbidden).
- **`clampLimit` uses `min` as default when `raw` is undefined**: callers must pass `?? N` to get a sensible default.
- **No separate DrillSession/DrillSessionService classes**: session state is managed inside `SpeakingDrillScreen`/`_DrillPromptCard` stateful widgets.
- **Admin speaking prompts route uses `PATCH`**, not `PUT`.

## Critical Context
- **Admin credential pattern in tests**: use `loadTestConfig({ ADMIN_API_TOKENS: 'token' })` + pass `{ headers: { 'x-expat8-admin-token': 'token' } }` directly to `fetchJson` (which signs internally). Never pre-wrap with `signedFetchOptions`.
- **`buildSpeakingSummary` signature changed**: now takes `firstRecordingAt` param; `getSpeakingSummary` computes it from all-time events.
- **`speaking_events` CHECK constraint**: old name `speaking_events_event_type_check`; migration DROPs and re-ADDs it.
- **No seed runner**: `backend/db/seeds/speaking_prompts_seed.sql` must be applied manually to Postgres.
- **`normalizeSpeakingEvent` validates `speaking_drill_completed`**: missing `prompts_attempted` or `total_duration_ms` → `missing_required_field`; negative values → `invalid_speaking_event`.
- **`SpeakingDrillScreen`** is fully wired — entry point in `LearningDrawer`, all drill events fire, navigate via `MaterialPageRoute`.
- **`flutter analyze`**: 3 warnings remain (unused `_config` field in `word_repository.dart`, unused import in `speaking_audio_service.dart`, unused `_selfRating` in `speaking_panel.dart`) — no errors.
- **ObjectBox entity upsert pattern**: query by `promptId` to find existing (get its `.id`), then `put()` with preserved ObjectBox id — avoids duplicates.
- **Build command**: `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release --dart-define BACKEND_BASE_URL=https://expat8.x51.vn --dart-define SPEAKING_FOUNDATION_ENABLED=true`

## Relevant Files
- `/home/beou/IdeaProjects/expat8/openspec/changes/complete-speaking-phase-0-3/tasks.md`: 57 tasks; 53 done; 4 remaining (manual QA 9.3–9.6).
- `/home/beou/IdeaProjects/expat8/backend/src/word_store.js`: `SPEAKING_EVENT_TYPES` (8 types), `getSpeakingSummary`, `buildSpeakingSummary`, `normalizeSpeakingEvent`, `listSpeakingPrompts`, `createSpeakingPrompt` — all updated.
- `/home/beou/IdeaProjects/expat8/backend/src/app.js`: `GET /v1/speaking/prompts`, `GET/POST /v1/admin/speaking-prompts`, `PATCH /v1/admin/speaking-prompts/:id` added.
- `/home/beou/IdeaProjects/expat8/backend/db/migrations/20260510_speaking_drill_completed.sql`: Nullable word_sense_id, drill columns, updated CHECK, new index.
- `/home/beou/IdeaProjects/expat8/backend/db/seeds/speaking_prompts_seed.sql`: 50 curated prompts; must be applied manually.
- `/home/beou/IdeaProjects/expat8/backend/test/api.test.js`: All admin + speaking API tests.
- `/home/beou/IdeaProjects/expat8/mobile/lib/src/speaking/speaking_repository.dart`: Fully rewritten — `SpeakingDrillRating`, fixed event types, all drill methods added.
- `/home/beou/IdeaProjects/expat8/mobile/lib/src/data/local_database.dart`: `getPromptsByWordSenseId()` + `upsertAllSpeakingPrompts()` added.
- `/home/beou/IdeaProjects/expat8/mobile/lib/src/api/backend_api_client.dart`: `fetchSpeakingPrompts()` + `SpeakingPromptItem` class added.
- `/home/beou/IdeaProjects/expat8/mobile/lib/src/speaking/speaking_prompt_sync_service.dart`: `SpeakingPromptSyncService.syncIfNeeded()` — created and wired.
- `/home/beou/IdeaProjects/expat8/mobile/lib/src/speaking/speaking_drill_screen.dart`: Fully implemented — all phases, events, summary screen. Bug fix: removed orphaned `_rating = rating` assignment.
- `/home/beou/IdeaProjects/expat8/mobile/lib/src/ui/learning_screen.dart`: "3-minute drill" `ListTile` added to `LearningDrawer`.
- `/home/beou/IdeaProjects/expat8/mobile/lib/main.dart`: `SpeakingPromptSyncService` instantiated and called with `unawaited(sync.syncIfNeeded())`.
- `/home/beou/IdeaProjects/expat8/expat8-dashboard/src/app/speaking-prompts/page.tsx`: Dashboard prompt review page with approve/reject actions.
- `/home/beou/IdeaProjects/expat8/expat8-dashboard/src/app/page.tsx`: Nav link to `/speaking-prompts` present in home header.
- `/home/beou/IdeaProjects/expat8/contracts/api.md`: Updated with `GET /v1/speaking/summary` (new fields), `GET /v1/speaking/prompts`, `GET /v1/admin/speaking-prompts`, `PATCH /v1/admin/speaking-prompts/:id`, `speaking_drill_completed` event type.
- `/home/beou/IdeaProjects/expat8/mobile/build/app/outputs/flutter-apk/app-release.apk`: 60.0MB release APK.
