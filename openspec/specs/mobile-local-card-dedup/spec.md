## Purpose

Prevent immediate re-selection of a word after it has been learned in the mobile local card queue, while keeping review scheduling consistent with the spaced-repetition gate.

## Requirements

### Requirement: markWordLearned advances nextReviewAtMs to prevent immediate re-selection
When the mobile app marks a word as learned, it SHALL set `nextReviewAtMs` to at least `now + 30 minutes`, or preserve the existing later value if one is already scheduled.

#### Scenario: Word learned for the first time
- **WHEN** `markWordLearned` is called for a word with `nextReviewAtMs = null`
- **THEN** `nextReviewAtMs` is set to `now + 30 minutes`

#### Scenario: Word has a future nextReviewAtMs from a prior schedule
- **WHEN** `markWordLearned` is called and the existing `nextReviewAtMs` is already beyond `now + 30 minutes`
- **THEN** `nextReviewAtMs` is preserved unchanged

#### Scenario: Word has a past or near-future nextReviewAtMs
- **WHEN** `markWordLearned` is called and the existing `nextReviewAtMs` is in the past or within the next 30 minutes
- **THEN** `nextReviewAtMs` is updated to `now + 30 minutes`

### Requirement: recentlyLearnedReviewWord respects nextReviewAtMs scheduling gate
The mobile app SHALL only return review candidates when `nextReviewAtMs IS NULL OR nextReviewAtMs <= now`, matching `nextDueReviewWord`.

#### Scenario: Word with future nextReviewAtMs is excluded
- **WHEN** `recentlyLearnedReviewWord` is queried and a candidate word has `nextReviewAtMs > now`
- **THEN** that word is not returned as a review candidate

#### Scenario: Word with null nextReviewAtMs is included
- **WHEN** `recentlyLearnedReviewWord` is queried and a candidate word has `nextReviewAtMs = null`
- **THEN** that word is eligible to be returned

#### Scenario: Word with past nextReviewAtMs is included
- **WHEN** `recentlyLearnedReviewWord` is queried and a candidate word has `nextReviewAtMs <= now`
- **THEN** that word is eligible to be returned

### Requirement: Right-to-left swipe on a new-word card awaits markWordAsLearning before advancing
When the user swipes right-to-left on a new-word card, the mobile app SHALL await `markWordAsLearning` before calling `nextCard()` so the word's status is committed before the next card is selected.

#### Scenario: User swipes right-to-left on a new-word card
- **WHEN** `onSwipeRightToLeft` is called and `currentCardKind == CardKind.newWord`
- **THEN** `markWordAsLearning` completes before `nextCard()` is invoked

#### Scenario: markWordAsLearning is called twice for the same word
- **WHEN** `markWordAsLearning` is called on a word that already has `status != newWord`
- **THEN** the call completes without error and the word's status is unchanged
