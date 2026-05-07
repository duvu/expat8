## 1. Database Schema & Persistence

> Current-state note (2026-05-06): completed `/v1/words/next` tasks in this
> file are historical records. The live card-loading path is
> `POST /v1/learning/cards`, and proficiency-aware selection should be
> understood through that endpoint plus study-event/proficiency state.

- [x] 1.1 Create `user_proficiency` table in `backend/db/schema.sql` with columns: id, device_id, language, level, created_at, updated_at
- [x] 1.2 Add unique constraint on (device_id, language) to `user_proficiency` table
- [x] 1.3 Add `rating` column (VARCHAR) to `study_events` table to store difficulty ratings (easy, too_easy, hard, too_hard)
- [x] 1.4 Create database migration script for schema changes
- [x] 1.5 Verify schema migration works in development and test environments
- [ ] 1.6 Create initial `user_proficiency` records for test devices at A1

## 2. Backend API: Study Events with Rating

- [x] 2.1 Modify `POST /v1/study-events` route to accept optional `rating` parameter
- [x] 2.2 Implement validation: rating must be one of (easy, too_easy, hard, too_hard) or reject with 400
- [x] 2.3 Store rating in `study_events.rating` column on submission
- [x] 2.4 Write unit tests for rating validation (valid/invalid values)
- [x] 2.5 Create integration test for study event submission with rating

## 3. Backend Logic: Consecutive Rating Counter

- [x] 3.1 Implement `countConsecutiveRatings(deviceId, rating)` function in backend
  - Query last 10 `study_events` for deviceId ordered by timestamp DESC
  - Count consecutive events matching the rating value
  - Return count (0–10)
- [x] 3.2 Implement `getLastRatingType(deviceId)` function to determine what rating type is currently being counted
- [x] 3.3 Write unit tests for consecutive counter logic (edge cases: empty events, mixed ratings, exactly 5, more than 5)
- [x] 3.4 Test out-of-order event handling (recompute count from DB on each submission)

## 4. Backend Logic: Proficiency Level Changes

- [x] 4.1 Implement `incrementProficiency(deviceId)` function that increases level by 1 (A1→A2, B2→B1, etc.)
  - Query current level from `user_proficiency`
  - Check boundaries (don't exceed C2)
  - Update level and `updated_at` timestamp
  - Return old and new level
- [x] 4.2 Implement `decrementProficiency(deviceId)` function that decreases level by 1
  - Check boundaries (don't drop below A1)
  - Update level and `updated_at` timestamp
  - Return old and new level
- [x] 4.3 Implement `initializeProficiency(deviceId)` function that creates new `user_proficiency` record at A1
  - If record already exists, return existing
  - Default language: 'en'
  - Set created_at and updated_at
- [x] 4.4 Write unit tests for proficiency level changes (boundary cases: A1 regress, C2 advance)
- [x] 4.5 Write unit tests for level initialization

## 5. Backend Logic: Proficiency Updates on Study Event

- [x] 5.1 Integrate consecutive counter logic into `POST /v1/study-events` endpoint
  - After storing event, compute consecutive count for the device
  - If count === 5 and rating === "too_easy", call `incrementProficiency(deviceId)`
  - If count === 5 and rating === "hard", call `decrementProficiency(deviceId)`
  - Return proficiency details in response
- [x] 5.2 Implement proficiency response format:
  - `proficiency.level`: current CEFR level
  - `proficiency.level_changed`: boolean
  - `proficiency.previous_level`: prior level (if changed)
  - `proficiency.triggered_by`: description (e.g., "5x consecutive too_easy")
  - `proficiency.consecutive_count`: current position (0–4) if no change
  - `proficiency.consecutive_rating_type`: rating type being counted
- [x] 5.3 Wrap read + update in database transaction for atomicity
- [x] 5.4 Write integration test: 5 consecutive "too_easy" triggers level-up
- [x] 5.5 Write integration test: 5 consecutive "hard" triggers level-down
- [x] 5.6 Write integration test: mixed ratings reset counter

## 6. Backend API: Proficiency Endpoints

- [x] 6.1 Implement `GET /v1/proficiency?device_id=<id>` endpoint
  - Query `user_proficiency` for device_id
  - If not found, initialize at A1
  - Return level, language, last_updated, consecutive_current_rating, current_rating_type
- [ ] 6.2 Implement authentication/authorization: allow device to query own proficiency (check device_id in request)
- [x] 6.3 Write unit tests for proficiency fetch
- [x] 6.4 Write integration test: new device auto-initializes at A1 on first proficiency query

## 7. Backend API: Word Filtering by Proficiency

- [x] 7.1 Historical/superseded: modify `GET /v1/words/next` route to accept optional `proficiency_level` parameter (current selection path is `POST /v1/learning/cards`)
- [x] 7.2 Enhance `findNewWords(targetLanguage, excludeWordIds, proficiencyLevel)` signature in word store
- [x] 7.3 Implement filtering in in-memory store: filter by `difficulty_level === proficiencyLevel`
- [x] 7.4 Implement filtering in PostgreSQL store: add WHERE clause `AND difficulty_level = $param`
- [x] 7.5 Implement fallback strategy if no words at exact level:
  - Try adjacent levels (A1→A2, B1→B2, etc.) in defined order
  - Return first available word
- [x] 7.6 Verify `exclude_server_word_id` still works with proficiency filtering
- [x] 7.7 Write unit tests for word filtering by proficiency level
- [x] 7.8 Write unit tests for fallback strategy (no exact match)
- [x] 7.9 Write integration test: word feed respects both proficiency and exclusions

## 8. Backend Content & Vocabulary Validation

- [x] 8.1 Verify all words in test data have valid CEFR difficulty level (A1–C2)
- [x] 8.2 Ensure LiteLLM generation prompt specifies target CEFR level (currently does "term-avoiding" only)
- [x] 8.3 Create validation function: `validateDifficultyLevel(word)` returns true if difficulty is A1–C2
- [x] 8.4 Add validation to word ingest/generation pipeline
- [ ] 8.5 Document legacy difficulty field mapping (beginner→A1, intermediate→B1, advanced→C1)

## 9. Mobile: Proficiency State Management

- [x] 9.1 Add `proficiency: {level: String, consecutive_count: int, consecutive_rating_type: String}` to app state (e.g., in `learning_session_controller.dart`)
- [x] 9.2 Implement `fetchProficiency(deviceId)` in `backend_api_client.dart` to call `GET /v1/proficiency`
- [x] 9.3 Call `fetchProficiency()` on app launch and cache result in state
- [x] 9.4 Implement `submitRating(wordId, rating)` function that calls `POST /v1/study-events` with rating
- [x] 9.5 Parse proficiency response and update app state (level, consecutive_count, etc.)
- [x] 9.6 Handle level-change response: set `proficiency.level_changed = true` to trigger notification
- [x] 9.7 Add device_id to API requests (derive from device properties or generate once and persist)

## 10. Mobile UI: Proficiency Display

- [x] 10.1 Create proficiency display widget in top-right corner of `learning_screen.dart`
  - Show current level (e.g., "A1", "B1", "C2")
  - Small font, subtle styling
  - Non-intrusive positioning
- [x] 10.2 Verify proficiency display is visible and readable on all phone sizes
- [x] 10.3 Implement real-time update: display changes after 5th consecutive rating triggers level change
- [x] 10.4 Write Flutter widget test for proficiency display rendering

## 11. Mobile UI: Rating Buttons

- [x] 11.1 Create 4-button rating bar layout in `learning_screen.dart`:
  - `Row` with 4 `ElevatedButton` or `OutlinedButton` children
  - Equal widths (use `Expanded` with `flex: 1`)
  - Order: "Easy", "Too Easy", "Hard", "Too Hard"
  - 56dp height minimum (Material Design standard)
  - Comfortable padding between buttons
- [x] 11.2 Implement button tap handlers: call `submitRating()` with corresponding rating value
- [x] 11.3 Add visual feedback on button press (highlight, ripple effect)
- [x] 11.4 Implement button label overflow handling (short labels, no wrapping)
- [x] 11.5 Add accessibility labels to buttons
- [ ] 11.6 Write Flutter widget test for rating button layout and taps
- [x] 11.7 Write widget test: all 4 buttons have equal width

## 12. Mobile UI: Level-Up Notification

- [x] 12.1 Implement level-up notification (alert/snackbar/overlay):
  - Show when proficiency level changes
  - Display previous level and new level
  - Optional animation (fade-in, scale, bounce)
  - Auto-dismiss after 2–3 seconds or user tap
- [x] 12.2 Handle level-down notification similarly
- [ ] 12.3 Test notification appears correctly on level change

## 13. Mobile: Integration with Word Fetching

- [x] 13.1 Modify `getNewWordWithFallback()` in `word_repository.dart` to include `proficiency_level` parameter
- [x] 13.2 Historical/superseded: call `GET /v1/words/next?proficiency_level=<current_level>&...` when fetching next word (current mobile refill uses `POST /v1/learning/cards`)
- [x] 13.3 Verify word filtering works after level change (next word should be at new level)
- [ ] 13.4 Test fallback behavior: if no exact-level words, app receives adjacent-level word

## 14. E2E Testing

- [ ] 14.1 Manual test: User starts app, completes 5 words, rates all "Too Easy", verifies level changes to A2
- [ ] 14.2 Manual test: User rates 5 words as "Hard", verifies level decreases
- [ ] 14.3 Manual test: User rates words with mixed ratings, verifies counter resets
- [ ] 14.4 Manual test: Level change notification appears and dismisses
- [ ] 14.5 Manual test: After level-up, next word is at new level
- [ ] 14.6 Manual test: Proficiency display in top-right updates in real time
- [ ] 14.7 Automated E2E test: Complete flow from app launch → fetch proficiency → rate 5 words → verify level change
- [ ] 14.8 Performance test: Proficiency update doesn't lag or freeze UI

## 15. Documentation & Deployment

- [x] 15.1 Update `contracts/api.md` with new/modified endpoints:
  - `GET /v1/proficiency`
  - Enhanced `POST /v1/study-events` with rating and proficiency response
  - Historical/superseded: enhanced `GET /v1/words/next` with proficiency_level parameter; current path is `POST /v1/learning/cards`
- [ ] 15.2 Update backend README with proficiency system overview
- [x] 15.3 Document CEFR level mapping and fallback strategy
- [x] 15.4 Document device initialization behavior (default A1)
- [ ] 15.5 Add migration guide for existing data (if any) regarding difficulty fields
- [ ] 15.6 Update mobile README with new rating buttons and proficiency display
- [ ] 15.7 Create or update architecture diagram showing proficiency system
- [ ] 15.8 Generate release notes summarizing adaptive proficiency feature

## 16. Code Review & Validation

- [ ] 16.1 Code review: Backend schema and migration
- [ ] 16.2 Code review: Backend proficiency logic (counter, level changes, transactions)
- [ ] 16.3 Code review: Backend API endpoints
- [ ] 16.4 Code review: Mobile state management and API integration
- [ ] 16.5 Code review: Mobile UI (proficiency display, rating buttons, notifications)
- [ ] 16.6 Security review: Ensure device_id in requests can't be spoofed (MVP: device isolation)
- [ ] 16.7 Accessibility review: Button text, contrast, touch targets, label accessibility

## 17. Optional: Analytics & Monitoring

- [ ] 17.1 Add telemetry: Track time-to-level-up, drop rates, rating distribution
- [ ] 17.2 Add backend logging for proficiency level changes (timestamp, device_id, old level, new level)
- [ ] 17.3 Add anomaly detection: Flag gaming patterns (5 "Too Easy" in < 1 minute)
- [ ] 17.4 Set up alerts for unexpected proficiency changes
- [ ] 17.5 Create dashboard: Monitor proficiency distribution across users/devices
