## 1. Database Migration

- [x] 1.1 Create migration `backend/db/migrations/<date>_exam_tables.sql` with `exam_attempts`, `exam_questions`, `exam_certificates` tables and indexes
- [x] 1.2 Add index on `exam_attempts(user_id, created_at DESC)` and `exam_questions(session_id)`
- [ ] 1.3 Run `npm run verify:migrations` to confirm migration is valid and in order

## 2. Backend — Exam Routes Scaffold

- [x] 2.1 Add exam route group file `backend/src/routes/exam.js` with route stubs for all 5 endpoints
- [x] 2.2 Mount `/v1/exam` router in `backend/src/app.js` with app-credential auth middleware
- [x] 2.3 Add `GET /v1/exam/certificate/:id` as a public route (no auth middleware — same pattern as `GET /health`)

## 3. Backend — Topic List Endpoint

- [x] 3.1 Implement `GET /v1/exam/topics?language=<lang>` in `word_store.js` and `postgres_word_store.js`: query distinct topics from studied words, normalise (lowercase, trim), return sorted array
- [x] 3.2 Write unit test for topic list with empty and non-empty studied-word states

## 4. Backend — Start Session Endpoint

- [x] 4.1 Implement `startExamSession()` in `WordStore`: collect source words matching topic+language from `user_word_states`, gate on min 5, cap at 20, build MCQ questions with `selectDistractors` + `shuffleChoices`
- [x] 4.2 Implement `startExamSession()` in `PostgresWordStore`: same logic via SQL
- [x] 4.3 Return `{ error: 'INSUFFICIENT_WORDS', found }` when fewer than 5 source words available
- [x] 4.4 Session expires after 2 hours (`expires_at` stored in session record)
- [x] 4.5 `POST /v1/exam/start` handler returns 422 for `INSUFFICIENT_WORDS`, 201 with full session payload on success
- [x] 4.6 Write unit tests for `startExamSession` (happy path, insufficient words, exactly-5 boundary, cap-at-20)

## 5. Backend — Submit Session Endpoint

- [x] 5.1 Implement `submitExamSession()` in `WordStore`: validate session exists (404), not already submitted (409), not expired (410), answer count match (422), score, persist attempt + certificate on pass
- [x] 5.2 Implement `submitExamSession()` in `PostgresWordStore`: same logic via SQL
- [x] 5.3 Certificate row created only when `score_pct >= 70`; uses `crypto.randomUUID()` (no prefix)
- [x] 5.4 `POST /v1/exam/submit` handler maps error codes to HTTP 404/409/410/422
- [x] 5.5 Write unit tests for `submitExamSession` (pass, fail, expired, duplicate, answer mismatch)

## 6. Backend — Exam Results Endpoint

- [x] 6.1 Implement `getExamResults()` in `WordStore`: paginated, newest-first, includes `certificate_id` if cert exists
- [x] 6.2 Implement `getExamResults()` in `PostgresWordStore`: same via SQL
- [x] 6.3 Write unit tests for `getExamResults` (empty, single, pagination)

## 7. Backend — Certificate Endpoint

- [x] 7.1 Implement `getExamCertificate()` in `WordStore`: returns public cert without user PII; null → 404
- [x] 7.2 Implement `getExamCertificate()` in `PostgresWordStore`: same via SQL
- [x] 7.3 Write unit tests for `getExamCertificate` (found, not found)

## 8. API Contract

- [x] 8.1 Add exam endpoint section to `contracts/api.md` covering all 5 endpoints with request/response shapes

## 9. Mobile — Data Layer

- [x] 9.1 Add `ExamAttemptEntity` to `mobile/lib/src/data/local_database_entities.dart`
- [x] 9.2 Add `examAttempts` box and CRUD helpers to `LocalDatabase`
- [x] 9.3 Add exam API methods to `BackendApiClient`: `fetchExamTopics`, `startExamSession`, `submitExamSession`, `fetchExamResults`, `fetchExamCertificate`

## 10. Mobile — ExamSessionController

- [x] 10.1 Create `mobile/lib/src/exam/exam_session_controller.dart` with `ExamSessionController` class
- [x] 10.2 States: `idle` → `loading` → `active` → `submitting` → `results`
- [x] 10.3 Methods: `startSession(topic, language)`, `submitAnswer(questionIndex, choiceIndex)`, `submitSession()`
- [x] 10.4 Persist result to local DB via `LocalDatabase.saveExamAttempt()`
- [x] 10.5 Write Flutter unit tests for `ExamSessionController`

## 11. Mobile — Exam UI Screens

- [x] 11.1 `ExamTopicScreen` — topic list from `fetchExamTopics`, language selector, start button (disabled if < 5 words)
- [x] 11.2 `ExamQuestionScreen` — one question at a time with 4-choice MCQ; immediate per-question feedback; "Next" button
- [x] 11.3 `ExamResultsScreen` — score display; certificate banner if passed; "Retake" and "Done" buttons
- [x] 11.4 `ExamCertificateScreen` — public certificate view; share button
- [x] 11.5 Register all 4 screens in `AppRouter` / navigation

## 12. Mobile — LearningScreen Entry Point

- [x] 12.1 Add "Take Exam" button/card to `LearningScreen`
- [x] 12.2 Navigate to `ExamTopicScreen` on tap

## 13. Dashboard — Exam Results Page

- [x] 13.1 Add `examResults(filters)` query to `expat8-dashboard/src/lib/db.ts`
- [x] 13.2 Create `expat8-dashboard/src/app/exam/page.tsx` with read-only table of all exam attempts
- [x] 13.3 Columns: user identifier, topic, language, score, pass/fail, date, certificate link
- [x] 13.4 Add "Exam Results" link to dashboard nav/home page
- [x] 13.5 Server-side rendered; no mutation controls
