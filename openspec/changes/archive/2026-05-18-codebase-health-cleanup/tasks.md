## 1. Dead Code and Phantom Dependencies

- [x] 1.1 Delete `backend/src/http_utils.js` (unused, zero imports)
- [x] 1.2 Remove `express-rate-limit` from `backend/package.json` dependencies
- [x] 1.3 Run `npm install` to update package-lock.json
- [x] 1.4 Remove `DebugTelemetrySink` class from `mobile/lib/src/telemetry.dart` (keep abstract `TelemetrySink` and `TelemetryEvent` enum)
- [x] 1.5 Run `npm test` in backend to verify no breakage
- [x] 1.6 Run `flutter test` in mobile to verify no breakage

## 2. Backend Shared Utilities Extraction

- [x] 2.1 Create `backend/src/routes/helpers.js` exporting `asyncHandler`, `bearerToken`, `resolveRequiredUserSession`, `resolveOptionalUserSession`
- [x] 2.2 Update `backend/src/routes/exam.js` to import from `./helpers.js` and remove local copies
- [x] 2.3 Update `backend/src/app.js` to import from `./routes/helpers.js` and remove local definitions
- [x] 2.4 Create `backend/src/store_utils.js` exporting `statusForRating`, `nextReviewForRating`, `normalizeWeekStart`
- [x] 2.5 Update `backend/src/word_store.js` to import from `./store_utils.js` and remove local definitions
- [x] 2.6 Update `backend/src/postgres_word_store.js` to import from `./store_utils.js` and remove local definitions
- [x] 2.7 Run `npm test` to verify all 167 tests pass

## 3. Backend Route Module Extraction

- [x] 3.1 Create `backend/src/routes/auth.js` — extract register, sign-in, sign-out handlers from app.js
- [x] 3.2 Create `backend/src/routes/admin.js` — extract all `/v1/admin/*` handlers from app.js
- [x] 3.3 Create `backend/src/routes/learning.js` — extract `/v1/learning/cards` handler from app.js
- [x] 3.4 Create `backend/src/routes/articles.js` — extract article CRUD handlers from app.js
- [x] 3.5 Create `backend/src/routes/speaking.js` — extract speaking summary/prompts handlers from app.js
- [x] 3.6 Create `backend/src/routes/proficiency.js` — extract proficiency GET handler from app.js
- [x] 3.7 Create `backend/src/routes/study_events.js` — extract study-events sync/create handlers from app.js
- [x] 3.8 Create `backend/src/routes/content_packs.js` — extract content-pack handlers from app.js
- [x] 3.9 Create `backend/src/routes/user.js` — extract `/v1/me`, `/v1/user-word-cache`, `/v1/words/recent`, `/v1/workplace-sentences/recent` handlers from app.js
- [x] 3.10 Refactor `backend/src/app.js` to mount all route modules and contain only middleware + router wiring (target: < 300 lines)
- [x] 3.11 Run `npm test` to verify all tests pass after extraction

## 4. Backend Seed Data Extraction

- [x] 4.1 Create `backend/src/seed_data.js` with all vocabulary seed data extracted from `word_store.js`
- [x] 4.2 Update `backend/src/word_store.js` to import seed data from `./seed_data.js`
- [x] 4.3 Verify `word_store.js` is under 1800 lines after extraction
- [x] 4.4 Run `npm test` to verify all tests pass

## 5. Mobile API Layer Reorganization

- [x] 5.1 Create `mobile/lib/src/api/models/learning_models.dart` — extract `LearningCardBatch`, `SyncResult`, `StudyEventResult`, `CacheInventoryResult`
- [x] 5.2 Create `mobile/lib/src/api/models/exam_models.dart` — extract `ExamSessionResponse`, `ExamQuestion`, `ExamSubmitResponse`, `ExamResultsPage`, `ExamCertificate`
- [x] 5.3 Create `mobile/lib/src/api/models/content_models.dart` — extract `ContentPack`, `ContentPackSummary`
- [x] 5.4 Create `mobile/lib/src/api/models/speaking_models.dart` — extract `SpeakingWeeklySummary`, `SpeakingPromptItem`
- [x] 5.5 Create `mobile/lib/src/api/models/user_models.dart` — extract user/session-related DTOs
- [x] 5.6 Add barrel exports in `backend_api_client.dart` to re-export all model files (backward compatibility)
- [ ] 5.7 Extract private `_request()` helper method in `BackendApiClient` to encapsulate stopwatch + timeout + logging + error handling pattern
- [ ] 5.8 Refactor all endpoint methods to use `_request()` helper
- [x] 5.9 Run `flutter test` to verify all 152 tests pass

## 6. Backend Dev Tooling

- [x] 6.1 Install ESLint 9+ and `@eslint/js` as devDependencies
- [x] 6.2 Create `backend/eslint.config.js` with flat config (ESM, recommended rules, globals for node)
- [x] 6.3 Install Prettier as devDependency
- [x] 6.4 Create `backend/.prettierrc` with single quotes and settings matching existing code style
- [x] 6.5 Add `lint`, `format`, and `format:check` scripts to `backend/package.json`
- [x] 6.6 Run `npm run lint` and fix any errors (not warnings) reported
- [x] 6.7 Run `npm run format` to format all files
- [x] 6.8 Run `npm test` to verify formatting didn't break anything

## 7. Admin API Documentation

- [x] 7.1 Document `POST /v1/admin/articles` (create article) in `contracts/api.md`
- [x] 7.2 Document `POST /v1/admin/articles/:id/publish` in `contracts/api.md`
- [x] 7.3 Document `POST /v1/admin/articles/:id/reprocess` in `contracts/api.md`
- [x] 7.4 Document `PATCH /v1/admin/vocabulary/:id` (approve/reject) in `contracts/api.md`
- [x] 7.5 Document `GET /v1/admin/log-archives` in `contracts/api.md`
- [x] 7.6 Document `GET /v1/admin/log-archives/:id` in `contracts/api.md`
- [x] 7.7 Document `GET /v1/admin/log-archives/:id/content` in `contracts/api.md`
- [x] 7.8 Verify documented request/response shapes match actual backend implementation

## 8. OpenSpec Housekeeping

- [x] 8.1 Archive `fix-exam-view-result-api-client` (all tasks complete)
- [ ] 8.2 Archive `build-production-android-apk` (all tasks complete)
- [ ] 8.3 Archive `mobile-learning-swipe-workflows-and-stats` (all tasks complete)
- [ ] 8.4 Archive `refine-workplace-sentence-copy-and-seed` (all tasks complete)
- [ ] 8.5 Archive `expat8-dashboard-admin-ops` (all tasks complete)

## 9. Final Verification

- [x] 9.1 Run full `npm test` in backend — all tests pass
- [x] 9.2 Run full `flutter test` in mobile — all tests pass
- [x] 9.3 Run `npm run lint` — zero errors
- [x] 9.4 Verify `backend/src/app.js` is under 300 lines
- [x] 9.5 Verify `backend/src/word_store.js` is under 1800 lines
- [x] 9.6 Verify `mobile/lib/src/api/backend_api_client.dart` contains no DTO class definitions other than `BackendApiClient` and `BackendApiException`
