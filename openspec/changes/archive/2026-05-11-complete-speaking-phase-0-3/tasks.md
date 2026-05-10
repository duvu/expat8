## 1. Backend: Database & Migration

- [x] 1.1 Create migration file `add_speaking_prompts_table` with columns: id, word_sense_id, target_text, vi_hint, pronunciation_tip_vi, common_mistake_vi, difficulty, topic, status (default 'pending_review'), created_at, updated_at
- [x] 1.2 Add index on `speaking_prompts(word_sense_id)` and `speaking_prompts(status)`
- [x] 1.3 Add composite index on `study_events(device_id, event_type, created_at)` for analytics queries
- [x] 1.4 Create seed file with 50 curated speaking prompts (A1-B1 level, work/daily/travel topics)
- [x] 1.5 Run `npm run verify:migrations` to confirm migration integrity

## 2. Backend: Extend Study Events Validation

- [x] 2.1 Add new speaking event types to the allowed list in event validator: `speaking_prompt_viewed`, `speaking_sample_played`, `speaking_retried`, `speaking_self_rated_hesitated`, `speaking_self_rated_could_not_say`, `speaking_drill_completed`
- [x] 2.2 Confirm speaking event types bypass proficiency update logic (no consecutive counter change)
- [x] 2.3 Add metadata schema validation for each new event type (required fields: prompt_id for viewed/played, attempt_id + retry_count for retried, attempt_id for self-rated, prompts_attempted + total_duration_ms for drill_completed)
- [x] 2.4 Write tests covering all 6 new event types accepted and stored
- [x] 2.5 Write test confirming speaking events do NOT affect proficiency level

## 3. Backend: Speaking Summary API

- [x] 3.1 Create route handler `GET /v1/speaking/summary` — require device_id header, return 401 if missing
- [x] 3.2 Implement aggregate query: count `speaking_recorded` events per device in rolling 7-day window
- [x] 3.3 Implement `retry_rate` calculation: `speaking_retried_count / speaking_recorded_count` (return 0 if no recordings)
- [x] 3.4 Implement `drill_sessions_completed` count from `speaking_drill_completed` events
- [x] 3.5 Add `first_recording_at` field (earliest `speaking_recorded` created_at for device, or null)
- [x] 3.6 Register route in `backend/src/server.js` under `/v1/speaking/summary`
- [x] 3.7 Write tests: zeroed response for new device, correct counts for seeded events, 401 for missing device_id

## 4. Backend: Admin Speaking Prompts API

- [x] 4.1 Create route handler `GET /v1/admin/speaking-prompts` — support `?status=` filter, pagination (`?page=&limit=`), require app credentials
- [x] 4.2 Create route handler `PUT /v1/admin/speaking-prompts/:id` — validate fields, update record, return updated object
- [x] 4.3 Create route handler `GET /v1/speaking/prompts` — return approved prompts only, used by mobile sync (paginated, optional `word_sense_id` filter)
- [x] 4.4 Register admin routes in server.js
- [x] 4.5 Write tests: list filter by status, update fields, reject unauthenticated request, confirm only approved prompts returned on mobile endpoint

## 5. Mobile: Speaking Prompts Sync & Storage

- [x] 5.1 Add `SpeakingPrompt` ObjectBox entity if not already defined: id, wordSenseId, targetText, viHint, pronunciationTipVi, commonMistakeVi, difficulty, topic, syncedAt
- [x] 5.2 Add `SpeakingPromptRepository` with methods: `getByWordSenseId`, `getDrillCandidates(limit: 5)`, `upsertAll`
- [x] 5.3 Add `SpeakingPromptSyncService` to fetch approved prompts from `GET /v1/speaking/prompts` and store in ObjectBox
- [x] 5.4 Integrate prompt sync into existing background sync flow (after word cache sync)
- [x] 5.5 Run `flutter pub run build_runner build --delete-conflicting-outputs` after ObjectBox entity changes
- [x] 5.6 Write unit tests for `getDrillCandidates` selection logic (priority order, fallback to recently learned)

## 6. Mobile: Drill Screen UI

- [x] 6.1 Create `DrillSession` model: list of 5 `DrillCard` (promptId, wordSenseId, targetText, viHint, attemptId, retryCount, selfRating, audioPath)
- [x] 6.2 Create `DrillSessionService`: builds session from `SpeakingPromptRepository.getDrillCandidates`, manages current card index, emits study events at each step
- [x] 6.3 Create `DrillScreen` widget: shows progress indicator (1/5), current card with word/phrase, targetText, viHint; buttons: Listen, Record, Play Back, Try Again, Skip
- [x] 6.4 Integrate existing `AudioRecorderService` and `AudioPlayerService` into drill card flow
- [x] 6.5 Create self-rating row: three buttons "Clear" / "Hesitated" / "Could not say it" — tapping advances to next card
- [x] 6.6 Create `DrillSummaryScreen`: shows sentences spoken, total duration, retry count, and encouraging message; "Done" button returns to home
- [x] 6.7 Add drill entry point to home screen and/or learning session end screen (only when `SPEAKING_FOUNDATION_ENABLED` is true)
- [x] 6.8 Wire `DrillScreen` routing in app navigation

## 7. Mobile: Speaking Events for Drill

- [x] 7.1 Emit `speaking_prompt_viewed` when drill card becomes active
- [x] 7.2 Emit `speaking_sample_played` when Listen button tapped
- [x] 7.3 Emit `speaking_retried` with updated `retry_count` when Try Again tapped
- [x] 7.4 Emit `speaking_self_rated_hesitated` / `speaking_self_rated_could_not_say` when corresponding rating tapped (in addition to existing `speaking_self_rated_clear`)
- [x] 7.5 Emit `speaking_drill_completed` on summary screen with `prompts_attempted`, `prompts_completed`, `total_duration_ms`
- [x] 7.6 Write widget tests: verify correct events queued for each user action in drill flow

## 8. Dashboard: Speaking Prompt Management

- [x] 8.1 Add Next.js API route `pages/api/speaking-prompts/index.ts` — proxy to `GET /v1/admin/speaking-prompts` with server-side app credentials
- [x] 8.2 Add Next.js API route `pages/api/speaking-prompts/[id].ts` — proxy to `PUT /v1/admin/speaking-prompts/:id`
- [x] 8.3 Create `pages/speaking-prompts.tsx` page with data table: word_sense, target_text, difficulty, status, updated_at columns
- [x] 8.4 Add status filter tabs: All / Pending Review / Approved / Rejected; show pending count badge
- [x] 8.5 Create prompt edit drawer/modal with fields: target_text (required), vi_hint, pronunciation_tip_vi, common_mistake_vi, difficulty dropdown, topic dropdown
- [x] 8.6 Add Approve / Reject buttons in row actions; confirmation on reject with optional reason field
- [x] 8.7 Add navigation link to speaking prompts page in dashboard sidebar

## 9. Verification & QA

- [x] 9.1 Run `cd backend && npm test` — all tests pass including new speaking event and summary tests
- [x] 9.2 Run `cd mobile && flutter test` — all tests pass including drill session and event emission tests
- [x] 9.3 Manual smoke test: start drill on device → record 5 sentences → see summary → verify events appear in backend logs
- [x] 9.4 Manual test: dashboard → speaking prompts page → edit a prompt → approve → confirm approved prompt returned by `GET /v1/speaking/prompts`
- [x] 9.5 Test offline drill: airplane mode → start drill → complete → reconnect → verify events sync
- [x] 9.6 Test permission denied: revoke microphone permission → open drill → confirm no crash, graceful message shown
- [x] 9.7 Rebuild APK: `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release --dart-define BACKEND_BASE_URL=https://expat8.x51.vn --dart-define SPEAKING_FOUNDATION_ENABLED=true`
- [x] 9.8 Update `contracts/api.md` with `GET /v1/speaking/summary`, `GET /v1/admin/speaking-prompts`, `PATCH /v1/admin/speaking-prompts/:id`, new event types
