## 1. Database Migration

- [x] 1.1 Create `backend/db/migrations/20260512_add_blank_word.sql` with `ALTER TABLE words ADD COLUMN IF NOT EXISTS blank_word TEXT;`
- [x] 1.2 Run `cd backend && npm run verify:migrations` against a local database to confirm the migration applies cleanly

## 2. Backend — Persistence Layer

- [x] 2.1 In `backend/src/postgres_word_store.js` `addWord()`: add `blank_word: input.blank_word ?? null` to the row object, add `blank_word` to the INSERT column list, add `$18` to the VALUES list, and add `row.blank_word` to the values array
- [x] 2.2 In `backend/src/word_store.js` in-memory `addWord()` equivalent: add `blank_word: input.blank_word ?? null` to stored word objects so in-memory and Postgres paths stay symmetric
- [x] 2.3 In `backend/src/word_store.js` `toApiWord()` (line 1543): add `blank_word: word.blank_word ?? null` to the returned object

## 3. Backend — LLM Prompt

- [x] 3.1 In `backend/src/litellm_client.js` CEFR prompt (line 190): extend the per-item description
- [x] 3.2 In `backend/src/litellm_client.js` CEFR prompt (line 194): add `entry_type` and `blank_word` to the required JSON fields list
- [x] 3.3 In `backend/src/litellm_client.js` HSK prompt (line 179): extend the per-item description similarly for `entry_type` and `blank_word`
- [x] 3.4 In `backend/src/litellm_client.js` HSK prompt (line 183): add `entry_type` and `blank_word` to the required JSON fields list

## 4. Backend — Validator / Enrichment Pass-Through

- [x] 4.1 In `backend/src/vocabulary_validator.js`: ensure `blank_word` from the LLM output is passed through to the validated item (do not strip it; it may be null)
- [x] 4.2 In `backend/src/vocabulary_enrichment_adapter.js` (article suggestion path): pass `blank_word: null` to maintain type symmetry (article suggestions do not go through the LLM vocab generation path)

## 5. Backend — Tests

- [x] 5.1 Add a test in the relevant backend test file for `toApiWord()`: assert `blank_word` is present in the returned object (null for a word-type input, non-null for a phrase-type input with `blank_word` set)
- [x] 5.2 Run `cd backend && npm test` — confirm all tests pass

## 6. Mobile — VocabularyWord Model

- [x] 6.1 In `mobile/lib/src/models/vocabulary_word.dart`: add `final String? blankWord;` field, add it to the constructor, `fromJson` (`json['blank_word'] as String?`), and `copyWith`

## 7. Mobile — canFitb Guard

- [x] 7.1 In `mobile/lib/src/session/learning_session_controller.dart`: add `bool canFitb(VocabularyWord word)` method
- [x] 7.2 Add a `bool shouldShowFitb(VocabularyWord word)` method

## 8. Mobile — FitbCard Widget

- [x] 8.1 Create `mobile/lib/src/ui/fitb_card.dart` with a `FitbCard` stateful widget
- [x] 8.2 In `FitbCard`: compute the blanked sentence
- [x] 8.3 Display the term, the blanked sentence, and a "Tap to reveal" affordance
- [x] 8.4 On tap anywhere on the card, set `_revealed = true` via `setState`
- [x] 8.5 Match the visual style of the existing `VocabularyCard` widget

## 9. Mobile — Wire FITB into Learning Screen

- [x] 9.1 In `mobile/lib/src/ui/learning_screen.dart` (or wherever `VocabularyCard` is rendered): import `fitb_card.dart` and `learning_session_controller.dart`
- [x] 9.2 When building the card widget for a `VocabularyWord`, call `controller.shouldShowFitb(word)`; if true, render `FitbCard(word: word)`, otherwise render the existing `VocabularyCard`

## 10. Mobile — Tests

- [x] 10.1 Write a unit test for `canFitb()`: assert false for a new card, false for an example with fewer than 8 words, false for an example that does not contain the term, false for a phrase/idiom with null `blankWord`, true for a valid review word
- [x] 10.2 Write a widget test for `FitbCard`: assert blanked sentence shows `"___"`, `exampleVi` is hidden; tap the card and assert the blanked word and `exampleVi` are revealed
- [x] 10.3 Run `cd mobile && flutter test` — confirm all tests pass

## 11. Verification

- [x] 11.1 Manual test on device or emulator: swipe through a session of ≥20 review cards and confirm approximately half show FITB mode
- [x] 11.2 Confirm tapping a FITB card reveals the word and Vietnamese hint without advancing the session
- [x] 11.3 Confirm phrase/idiom cards with null `blank_word` render as standard vocabulary cards (not FITB)
