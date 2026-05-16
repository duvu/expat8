## ADDED Requirements

### Requirement: Learning card response includes blank_word field
The learning cards API SHALL include the `blank_word` field in each card item within `POST /v1/learning/cards` responses, passing through the stored value (which may be null for older or word-type entries).

#### Scenario: Card response includes blank_word for phrase entry
- **WHEN** a phrase or idiom vocabulary item is included in a `POST /v1/learning/cards` response
- **THEN** the card item contains a `blank_word` field set to the stored value (non-null if populated by the LLM)

#### Scenario: Card response includes null blank_word for word entry
- **WHEN** a word-type vocabulary item is included in a `POST /v1/learning/cards` response
- **THEN** the card item contains a `blank_word` field that is null or absent

#### Scenario: Old rows without blank_word serve gracefully
- **WHEN** a card item is served from a row that predates the `blank_word` column
- **THEN** the card response includes `blank_word: null` without error
