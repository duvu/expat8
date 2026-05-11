## 1. Backend DB Migration

- [x] 1.1 Write migration SQL: `ALTER TABLE words ADD COLUMN entry_type TEXT NOT NULL DEFAULT 'word'` and `ALTER TABLE words ADD COLUMN explanation TEXT NOT NULL DEFAULT ''`
- [x] 1.2 Add migration file to `backend/db/migrations/` and register it in the migration runner
- [x] 1.3 Update `backend/db/schema.sql` to include both new columns
- [x] 1.4 Run `npm run verify:migrations` to confirm migration applies cleanly

## 2. Backend Word Model & Insertion

- [x] 2.1 Add `entry_type` and `explanation` fields to the word schema in `insertWord` (both `WordStore` and `PostgresWordStore`)
- [x] 2.2 Update `toApiWord` serializer to include `entry_type` and `explanation` in API responses
- [x] 2.3 Update `rowToWord` (Postgres) to read `entry_type` and `explanation` from DB rows
- [x] 2.4 Update existing seed words in `word_store.js` to include `entry_type: 'word'` and `explanation: ''`
- [x] 2.5 Add seed phrase entries (at least 10) for `language: 'en'` with `entry_type: 'phrase'` and populated `explanation`
- [x] 2.6 Add seed idiom entries (at least 20) for `language: 'en-idioms'` with `entry_type: 'idiom'` and populated `explanation`
- [x] 2.7 Add seed idiom entries (at least 20) for `language: 'zh-idioms'` (成语) with `entry_type: 'idiom'` and `explanation` in Vietnamese

## 3. Backend Exam — Dual Question Types

- [x] 3.1 Extend exam question shape in `startExamSession` to include `question_type` field (`meaning_choice` | `sentence_context`)
- [x] 3.2 Implement question type assignment logic: entries with non-empty `example` are eligible for `sentence_context`; randomly assign 50/50; entries with empty `example` always get `meaning_choice`
- [x] 3.3 For `sentence_context` questions, include `sentence` (the `example` value) and `highlight` (the `term`) in the question object
- [x] 3.4 Update exam API contract in `contracts/api.md`: add `question_type`, `sentence`, `highlight` to exam question shape; add `entry_type`, `explanation` to word card shape
- [x] 3.5 Update in-memory `WordStore.startExamSession` to match Postgres implementation

## 4. Backend Tests

- [x] 4.1 Add unit test: `startExamSession` assigns `meaning_choice` when `example` is empty
- [x] 4.2 Add unit test: `startExamSession` assigns `sentence_context` (with `sentence` + `highlight`) when `example` is non-empty
- [x] 4.3 Add unit test: `startExamSession` produces both question types in a session with a mixed pool
- [x] 4.4 Add unit test: `toApiWord` includes `entry_type` and `explanation` in the response shape
- [x] 4.5 Add unit test: phrase/idiom inserted with empty `ipa` and empty `part_of_speech` is accepted without error
- [x] 4.6 Run `cd backend && npm test` — all tests pass

## 5. Mobile Data Model

- [x] 5.1 Add `entryType` (`String`, default `'word'`) and `explanation` (`String`, default `''`) fields to the `Word` entity / model class
- [x] 5.2 Update `Word.fromJson` to parse `entry_type` and `explanation` from API response
- [x] 5.3 Add `questionType` (`String`), `sentence` (`String?`), and `highlight` (`String?`) fields to the exam question model
- [x] 5.4 Update the exam question `fromJson` to parse the new fields
- [x] 5.5 Run ObjectBox codegen if `Word` is an ObjectBox entity: `flutter pub run build_runner build --delete-conflicting-outputs`

## 6. Mobile Card Rendering

- [x] 6.1 In the learning card widget, add a branch on `entryType`: if `'phrase'` or `'idiom'`, hide the IPA row and part-of-speech label
- [x] 6.2 For phrase/idiom cards, show `explanation` text prominently when non-empty (above or replacing the `meaning_vi` display)
- [x] 6.3 Write widget test: word card renders IPA and POS; phrase card does not

## 7. Mobile Exam — Sentence Context Layout

- [x] 7.1 In the exam question widget, branch on `questionType`: if `'sentence_context'`, display the `sentence` text with `highlight` term visually emphasized (bold or underlined) above the answer choices
- [x] 7.2 Ensure the answer choice tap and submission flow is identical for both question types
- [x] 7.3 Write widget test: `meaning_choice` question shows term only; `sentence_context` question shows sentence with highlighted term

## 8. Mobile Language Picker — Idiom Tracks & Persistence

- [ ] 8.1 Add `'en-idioms'` and `'zh-idioms'` options to the `ExamTopicScreen` language picker dropdown
- [ ] 8.2 On `initState`, read the last-used exam language from `SettingsRepository` (ObjectBox); default to `'en'` if not set
- [ ] 8.3 On language change in the picker, persist the new value to `SettingsRepository`
- [ ] 8.4 Write widget test: language picker defaults to `'en'` on first launch; persists selected value across rebuilds

## 9. Mobile Test Suite

- [ ] 9.1 Run `cd mobile && flutter test` — all tests pass (target: existing count + new tests from tasks 6.3, 7.3, 8.4)
