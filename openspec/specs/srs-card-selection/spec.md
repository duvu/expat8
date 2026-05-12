## Purpose
Define how the backend selects and mixes review and new vocabulary cards for learning sessions, including the 85/15 allocation and due-date computation via the spaced-repetition rating system.
## Requirements
### Requirement: learningCards returns a mix of review and new cards
The `POST /v1/learning/cards` endpoint SHALL return due review cards alongside new cards. When the requested `count` can be satisfied by due review items, review cards SHALL make up approximately 85% of the response and new cards the remaining 15%. If fewer review cards are due than the 85% quota, the remainder is filled with new cards.

#### Scenario: Due review cards are available
- **WHEN** a client requests learning cards and there are due review items (where `next_review_at` ≤ current time)
- **THEN** the response includes review cards up to 85% of the requested count, with new cards filling the rest

#### Scenario: No due review cards
- **WHEN** a client requests learning cards and no review items are due
- **THEN** the response contains only new cards up to the requested count

#### Scenario: Fewer review cards than quota
- **WHEN** fewer due review cards exist than 85% of the requested count
- **THEN** all available due review cards are included and new cards fill the remainder to reach the requested count

#### Scenario: Card response includes review metadata
- **WHEN** a card is a review card
- **THEN** the response item includes `card_type: "review"` and the original `word_sense_id` linked to prior study events

#### Scenario: Card response for new card
- **WHEN** a card is a new card
- **THEN** the response item includes `card_type: "new"`

### Requirement: Review card due date is set by the rating system
When the backend stores a study event with a rating, it SHALL compute and persist `next_review_at` for the associated vocabulary item using the spaced-repetition schedule. `learningCards` uses this field to determine which items are due.

#### Scenario: Study event with rating is submitted
- **WHEN** a study event with a valid rating (e.g., 1–5) is submitted for a word sense
- **THEN** the backend computes `next_review_at` and persists it on the review record for that word sense

#### Scenario: Due card query respects next_review_at
- **WHEN** `learningCards` queries for due review items
- **THEN** only items where `next_review_at` ≤ now are considered due

### Requirement: Card response includes entry_type and explanation
The `POST /v1/learning/cards` response item shape SHALL include `entry_type` and `explanation` fields alongside the existing word fields so mobile clients can adapt card rendering based on whether an item is a word, phrase, or idiom.

#### Scenario: Card item carries entry_type for a word
- **WHEN** `POST /v1/learning/cards` returns an item for a standard word entry
- **THEN** the item includes `entry_type: 'word'` and `explanation: ''` (or the stored explanation value)

#### Scenario: Card item carries entry_type for a phrase
- **WHEN** `POST /v1/learning/cards` returns an item for a phrase entry
- **THEN** the item includes `entry_type: 'phrase'` and a non-empty `explanation` describing meaning, register, and usage

#### Scenario: Card item carries entry_type for an idiom
- **WHEN** `POST /v1/learning/cards` returns an item for an idiom entry
- **THEN** the item includes `entry_type: 'idiom'` and a non-empty `explanation` describing the non-literal meaning and cultural context

#### Scenario: IPA and part_of_speech may be empty for phrase and idiom cards
- **WHEN** a phrase or idiom card is returned
- **THEN** `ipa` and `part_of_speech` fields MAY be empty strings; the mobile client MUST NOT crash or display empty IPA/POS rows

