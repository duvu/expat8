## ADDED Requirements

### Requirement: Words table carries entry_type and explanation fields
The `words` table SHALL include an `entry_type` column with values `word`, `phrase`, or `idiom`, and an `explanation` column containing a contextual description of meaning, register, and usage. Both columns SHALL have non-null defaults (`word` and `''` respectively) so existing rows are unaffected by the migration.

#### Scenario: New word entry inserted without explicit entry_type
- **WHEN** a word is inserted without specifying `entry_type`
- **THEN** the stored `entry_type` is `'word'` and `explanation` is `''`

#### Scenario: Phrase entry inserted with explanation
- **WHEN** a phrase entry is inserted with `entry_type: 'phrase'` and a non-empty `explanation`
- **THEN** the stored row has `entry_type = 'phrase'` and `explanation` contains the provided text

#### Scenario: Idiom entry inserted with explanation
- **WHEN** an idiom entry is inserted with `entry_type: 'idiom'` and a non-empty `explanation`
- **THEN** the stored row has `entry_type = 'idiom'` and `explanation` contains the provided text

#### Scenario: IPA and part_of_speech may be empty for non-word entries
- **WHEN** a phrase or idiom entry is inserted with empty `ipa` and empty `part_of_speech`
- **THEN** the backend MUST accept the entry without validation error

### Requirement: API word shape includes entry_type and explanation
The `POST /v1/learning/cards` response word shape SHALL include `entry_type` and `explanation` fields so mobile clients can adapt rendering.

#### Scenario: Word card includes entry_type and explanation
- **WHEN** `POST /v1/learning/cards` returns a card
- **THEN** each item in `items` includes `entry_type` (one of `word`, `phrase`, `idiom`) and `explanation` (string, may be empty)

#### Scenario: Existing word cards carry default entry_type
- **WHEN** a card corresponds to a row where `entry_type` was not explicitly set
- **THEN** the response item has `entry_type: 'word'`

### Requirement: Mobile card layout adapts to entry_type
The mobile learning card widget SHALL render different layouts based on `entry_type`.

#### Scenario: Word card shows IPA and part of speech
- **WHEN** a card has `entry_type: 'word'`
- **THEN** the card displays the IPA string and part-of-speech label

#### Scenario: Phrase card suppresses IPA and part of speech
- **WHEN** a card has `entry_type: 'phrase'`
- **THEN** the card does NOT display an IPA row or part-of-speech label

#### Scenario: Idiom card suppresses IPA and part of speech
- **WHEN** a card has `entry_type: 'idiom'`
- **THEN** the card does NOT display an IPA row or part-of-speech label

#### Scenario: Phrase or idiom card shows explanation when non-empty
- **WHEN** a card has `entry_type: 'phrase'` or `entry_type: 'idiom'` and a non-empty `explanation`
- **THEN** the card displays the `explanation` text prominently, above or in place of the `meaning_vi` line
