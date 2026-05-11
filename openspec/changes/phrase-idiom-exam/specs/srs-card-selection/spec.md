## ADDED Requirements

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
