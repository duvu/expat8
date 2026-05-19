## 1. Backend immediate add-word resolution

- [x] 1.1 Update `backend/src/word_store.js` so `createUserSubmittedWord()` resolves non-existing words synchronously via the submitted-word generation path instead of creating queued jobs
- [x] 1.2 Update `backend/src/postgres_word_store.js` so `createUserSubmittedWord()` resolves non-existing words synchronously in the request transaction and no longer creates learner-visible queued jobs for the normal flow
- [x] 1.3 Keep existing-word deduplication behavior intact and ensure repeated submissions reuse terminal ready results when appropriate
- [x] 1.4 Define terminal failure behavior for in-request AI generation failures and return a consistent learner-facing response shape from `backend/src/routes/user.js`

## 2. Backend contract and verification

- [x] 2.1 Update `contracts/api.md` for `POST /v1/user-submitted-words` and `GET /v1/user-submitted-words` to document immediate resolution and the removal of normal queued/processing flow expectations
- [x] 2.2 Add backend tests for immediate existing-word resolution, immediate generated-word resolution, and immediate failure behavior
- [x] 2.3 Run `cd backend && npm test`

## 3. Mobile immediate import and learned-state handling

- [x] 3.1 Update `mobile/lib/src/data/word_repository.dart` so `submitSubmittedWord()` performs a direct request/response flow instead of enqueueing create/status sync work for the normal add-word path
- [x] 3.2 Update the submitted-word/local-word merge path so importing a resolved word preserves stronger existing local progress instead of resetting reviewed/mastered items back to `newWord`
- [x] 3.3 After a successful add-word response, import the resolved word into local vocabulary and record it as one learned exposure in local history/progress
- [x] 3.4 Update `mobile/lib/src/models/submitted_word.dart` and any local submitted-word persistence helpers to reflect the immediate terminal-response flow

## 4. Mobile UI and tests

- [x] 4.1 Update `mobile/lib/src/ui/submitted_words_screen.dart` copy, loading states, and feedback messages to reflect immediate existing-word/generated-word/failure outcomes
- [x] 4.2 Update mobile API/repository/widget tests for immediate add-word success, failure, local import, and learned-count/history effects
- [x] 4.3 Run `cd mobile && flutter test`

## 5. End-to-end review

- [ ] 5.1 Manually verify: entering a word that already exists returns immediately, appears in local study inventory, and counts as one learned item
- [ ] 5.2 Manually verify: entering a new word triggers backend AI generation in-request, persists the new canonical word, appears in local study inventory, and counts as one learned item
- [ ] 5.3 Manually verify: add-word request failure shows an immediate failure state and does not leave the learner in queued/processing limbo
