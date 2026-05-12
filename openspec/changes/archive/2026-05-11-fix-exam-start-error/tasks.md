## 1. Backend Route Fix

- [x] 1.1 Remove `topic` variable extraction and `if (!topic)` validation block from `POST /v1/exam/start` handler in `backend/src/routes/exam.js`
- [x] 1.2 Remove `topic` from the `store.startExamSession(...)` call arguments in the same handler
- [x] 1.3 Update the `INSUFFICIENT_WORDS` error message to reference `language` instead of `topic`

## 2. Backend Tests

- [x] 2.1 Update `backend/test/exam.test.js` exam-start tests to confirm language-only body returns 201 (remove any `topic` from test request bodies)
- [x] 2.2 Run `cd backend && npm test` and confirm all tests pass

## 3. Verification

- [x] 3.1 Manual verify on emulator: tap "Take Exam" → exam starts successfully (no "Failed to start exam" error)
