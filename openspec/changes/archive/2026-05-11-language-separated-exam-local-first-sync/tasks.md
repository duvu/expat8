## 1. Language-Separated Exam Flow

- [x] 1.1 Update exam question generation to use the active language as the only content source
- [x] 1.2 Prevent cross-language prompts, choices, and distractors from appearing in exam UI
- [x] 1.3 Preserve the selected language through the results screen

## 2. Local-First Result Persistence

- [x] 2.1 Persist completed exam results locally before backend sync begins
- [x] 2.2 Queue exam results for background sync with a stable idempotency key
- [x] 2.3 Keep the completion flow responsive when sync is slow or offline

## 3. Backend Sync and Retry

- [x] 3.1 Add or update backend exam-result ingestion to accept repeated sync attempts safely
- [x] 3.2 Mark local exam results as synced only after backend acknowledgment
- [x] 3.3 Retry failed sync attempts without blocking the user

## 4. Verification

- [x] 4.1 Add tests proving English exams never contain Chinese content
- [x] 4.2 Add tests proving Chinese exams never contain English content
- [x] 4.3 Add tests proving exam results are saved locally before sync and survive backend failure
- [x] 4.4 Run the relevant mobile and backend test suites
