## Context

The mobile app already has local-first card selection with `newWord`, `learning`, `review`, and `mastered` local statuses. Logs from a real device show repeated `new_word.local.empty` warnings after swipes, while the database still has cached server word ids. The current controller can request new-word-biased selection on right-to-left swipes, and the existing `CardSelectionWindow` targets 3 new cards per 10-card window. The user requirement is stricter: normal learning should be 15% new words and 85% review, and exhaustion of new words should not produce an empty card when learned/reviewable cards exist.

The backend Chinese generation path has a second mismatch. The product rule is language-profile based: English uses IPA, while Chinese does not have IPA and must use pinyin. `litellm_client.js` already tells the model that Chinese `ipa` may be empty and pinyin-style `vietnamese_pronunciation` is required, but `vocabulary_validator.js` currently treats an empty string as a missing required field before it reaches the Chinese-specific exception. This causes `ai_generation_item_rejected` warnings with `reason: missing_ipa` for valid Chinese candidates that include usable pinyin.

## Goals / Non-Goals

**Goals:**
- Make normal session progression target exactly 15% new cards and 85% review cards over a practical rolling window.
- Fall back to already learned/reviewable cards when the new-word pool is empty.
- Add diagnostic logs that explain card-selection intent, selected source, fallback chain, and final empty-card cause.
- Make pronunciation validation explicitly language-profile aware: English requires IPA; Chinese requires pinyin and does not require IPA.
- Fix Chinese validation so empty `ipa` is accepted only for Chinese items with valid pinyin.
- Keep English validation strict about IPA.

**Non-Goals:**
- Change backend networking, timeout behavior, or mobile retry policy for unreachable backend URLs.
- Redesign spaced repetition scheduling.
- Add new vocabulary fields or database columns. In the current schema, Chinese pinyin is carried in the existing `vietnamese_pronunciation` pronunciation slot.
- Accept Chinese generated items without any usable pronunciation guidance.

## Decisions

### D1: Represent 15/85 with a 20-card rolling window

Use a 20-card rolling selection window with `targetNewCards = 3`, yielding exactly 15% new cards and 85% review cards. This is more precise than trying to approximate 15% inside the existing 10-card window.

Alternative considered: probabilistic random selection at 15/85 on every swipe. Rejected because it can cluster new cards and is harder to assert in tests.

### D2: Centralize mixed-card selection in one controller path

Introduce a single mixed-selection helper in `LearningSessionController` that chooses the preferred card kind from the rolling window, then tries fallback paths in a deterministic order. Right-to-left "next card" should use this mixed path instead of forcing 85% new-card bias. Review-specific interactions can still prefer review first, but must not show an empty state if a valid fallback card exists.

Proposed fallback order for mixed selection:

```text
preferred kind from 20-card window
        │
        ├─ review preferred: due/difficult/recent review -> new word
        └─ new preferred: new word -> due/difficult/recent review
                         │
                         ▼
                    empty only if both pools empty
```

The exact review lookup can reuse existing local database methods: `nextDifficultRelearnWord`, `getRecentReviewWordResult`, and `nextDueReviewWord` through repository helpers. If implementation finds a missing local query for "any learned card", add the smallest local-database helper needed to retrieve a `learning`, `review`, or `mastered` card scoped by active language.

### D3: Log the decision tree, not only the final miss

Keep `new_word.local.empty`, but add higher-signal events around card selection:
- selection start with requested mode and active language
- preferred kind and current rolling-window counts
- fallback from unavailable new to review, or review to new
- selected source (`new`, `due_review`, `recent_review`, `difficult_relearn`, `learned_fallback`)
- final empty state with counts or attempted sources when no card exists

These logs should be persisted through the existing mobile logger and therefore exportable through the log-share feature.

### D4: Validate pronunciation by language profile

Change validation ordering so "required fields" are language-profile aware. For English, `ipa` is the accepted pronunciation metadata and empty `ipa` remains rejected. For Chinese, IPA is not required; pinyin is the required pronunciation metadata. In the current API and database shape, that pinyin must be supplied in `vietnamese_pronunciation` as pinyin-style romanization.

The logged rejection reason for a Chinese candidate with empty IPA and valid pinyin should no longer be `missing_ipa`; it should be accepted if all other fields pass. A Chinese candidate with missing, non-romanized, or non-pinyin pronunciation should still be rejected with a pronunciation-specific reason.

## Risks / Trade-offs

- [Risk] A stricter 15/85 target may feel slower for users who intentionally swipe for new words. -> Mitigation: keep explicit review/new fallback behavior visible in logs and tests; revisit gesture semantics separately if product wants mode-specific overrides.
- [Risk] Review fallback may surface mastered cards too often when due review is empty. -> Mitigation: prefer due/difficult/recent review before broader learned fallback.
- [Risk] Extra logs can become noisy. -> Mitigation: use structured, low-cardinality event names and include compact context instead of verbose messages.
- [Risk] Relaxing Chinese IPA validation could admit low-quality pronunciation data. -> Mitigation: require pinyin-style romanization and add tests for both accepted pinyin and rejected non-pinyin strings.
