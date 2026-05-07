## 1. Mobile Selection and Fallback

- [x] 1.1 Add or update focused tests for the 15% new / 85% review rolling selection behavior.
- [x] 1.2 Change `CardSelectionWindow` or its replacement scheduler to represent three new cards in a twenty-card rolling window.
- [x] 1.3 Replace gesture-biased random selection paths with a centralized selector that respects the 15/85 session contract.
- [x] 1.4 Add a learned/review fallback path so an exhausted new-word pool falls back to due, difficult, recent, or already-learned review cards before showing an empty card.
- [x] 1.5 Preserve a final empty state only when both new-word and learned/review fallback pools are unavailable.
- [x] 1.6 Update the learning-screen hint text to match the final gesture and session behavior.

## 2. Mobile Diagnostic Event Logs

- [x] 2.1 Add structured logs for card-selection start, including requested mode, active language, preferred kind, and rolling-window state.
- [x] 2.2 Add structured logs when selection falls back from new-word candidates to review/learned candidates.
- [x] 2.3 Add structured logs when selection falls back from review/learned candidates to new-word candidates.
- [x] 2.4 Add structured logs for final empty-card causes, including attempted sources and active language.
- [x] 2.5 Add or update mobile logging/session tests to assert the new diagnostic events without relying on backend connectivity.

## 3. Backend Chinese Generation Validation

- [x] 3.1 Add backend regression tests showing English items with non-empty `ipa` are accepted and English items with empty `ipa` are rejected with an IPA-specific reason.
- [x] 3.2 Add backend regression tests showing Chinese items with empty `ipa` and valid pinyin in `vietnamese_pronunciation` are accepted.
- [x] 3.3 Keep or add backend tests showing Chinese items without valid pinyin in `vietnamese_pronunciation` are rejected with a pinyin-specific reason, even if `ipa` is present.
- [x] 3.4 Refactor `validateVocabularyItem()` so required-field validation is language-profile aware: English requires `ipa`, Chinese requires pinyin and does not require `ipa`.
- [x] 3.5 Verify generation-service warning context reports useful rejection reasons for Chinese pinyin failures instead of `missing_ipa`.

## 4. Validation

- [x] 4.1 Run targeted mobile tests for card selection, learning session controller, repository fallback, and logs.
- [x] 4.2 Run targeted backend generation and validator tests.
- [x] 4.3 Run `openspec validate fix-empty-card-and-chinese-ipa --strict`.
- [x] 4.4 Search current specs and docs for stale 30/70 or `missing_ipa` Chinese guidance and update it if needed during implementation.
- [x] 4.5 Before archiving, normalize touched main specs if archive validation reports legacy delta headers in accepted spec files.
