## Why

Mobile logs show repeated `new_word.local.empty` events after several swipes, even though the session rule should prefer review cards and should fall back to already learned cards when new words are exhausted. Backend generation logs also show Chinese items rejected as `missing_ipa`, contradicting the Chinese profile where Chinese does not use IPA and must use pinyin.

## What Changes

- Enforce a 15% new-card / 85% review-card target for normal session progression.
- Prevent empty-card states when new words are exhausted by falling back to learned/reviewable cards before showing an empty message.
- Add mobile diagnostic events that explain card-selection intent, fallback path, and final empty-card causes.
- Fix vocabulary generation validation so English items require IPA and Chinese items require pinyin instead of IPA.
- Preserve strict rejection for Chinese items missing usable pinyin support.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mobile-learning-session`: Enforce the 15% new / 85% review learning mix and learned-card fallback when new cards are unavailable.
- `mobile-system-logging`: Add card-selection and empty-card diagnostic events for support/debugging.
- `ai-vocabulary-generation`: Align generation validation with language profiles: English accepts IPA, while Chinese accepts pinyin and does not require IPA.

## Impact

- **Mobile session**: `mobile/lib/src/session/learning_session_controller.dart`, `mobile/lib/src/session/card_selection.dart`, local review lookup paths, and session/controller tests.
- **Mobile logging**: persisted structured events around selection intent, fallback, empty pool, and selected card source.
- **Backend generation**: `backend/src/vocabulary_validator.js`, `backend/src/generation_service.js`, LiteLLM generation tests, and generation validation tests.
- **Specs/tests**: Update OpenSpec requirements for learning-session mix/fallback, mobile diagnostic logging, and Chinese generation validation.
