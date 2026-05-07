## ADDED Requirements

### Requirement: New word advances to learning status when first displayed
When a word with status `newWord` is shown via `showNewWord()`, the system SHALL immediately transition the word to `learning` status with `nextReviewAtMs = now + 24h` and `lastSeenAtMs = now`, so that subsequent calls to `nextNewWord()` return a different word.

#### Scenario: Swipe right-to-left advances through distinct new words
- **WHEN** the user swipes right-to-left multiple times
- **THEN** each swipe displays a different new word (not the same word repeatedly)

#### Scenario: Shown new word is removed from new-word pool
- **WHEN** `showNewWord()` displays a word with `actualKind == CardKind.newWord`
- **THEN** that word's status is changed to `learning` and it no longer appears in `nextNewWord()` results

#### Scenario: Fallback to review does not trigger advance
- **WHEN** `showNewWord()` cannot find a `newWord` and falls back to a review word
- **THEN** the review word's status is NOT changed

## MODIFIED Requirements

### Requirement: Session targets three new words and seven review words
The mobile app SHALL target a ratio of 3 new-word cards and 7 review-word cards across each 10-card learning window. Words transitioned to `learning` via display are counted as active learning cards and scheduled for review within 24 hours.

#### Scenario: New word target met in a 10-card window
- **WHEN** the learning session renders 10 cards in a window
- **THEN** the app targets 3 new-word cards and 7 review-word cards in that window

#### Scenario: Displayed new word appears in review queue within 24h
- **WHEN** a `newWord` is displayed and advanced to `learning`
- **THEN** `nextDueReviewWord(now + 24h)` can return that word for review
