## ADDED Requirements

### Requirement: LLM vocabulary generation outputs blank_word for phrase and idiom entries
The backend LLM generation prompt SHALL request a `blank_word` field for every `phrase` and `idiom` vocabulary entry, containing the single most semantically identifying content word of the phrase that is suitable for FITB blanking.

#### Scenario: Phrase entry is generated
- **WHEN** the LLM generates a vocabulary item with `entry_type == "phrase"`
- **THEN** the generated JSON includes a `blank_word` field containing the most semantically loaded content word of the phrase as it appears in the `example` sentence

#### Scenario: Idiom entry is generated
- **WHEN** the LLM generates a vocabulary item with `entry_type == "idiom"`
- **THEN** the generated JSON includes a `blank_word` field containing the most semantically loaded content word of the idiom as it appears in the `example` sentence

#### Scenario: Word entry type omits blank_word
- **WHEN** the LLM generates a vocabulary item with `entry_type == "word"`
- **THEN** the `blank_word` field is absent or null; the backend stores null in the `blank_word` column

#### Scenario: blank_word value is present in the example sentence
- **WHEN** a phrase or idiom item is accepted with a non-null `blank_word`
- **THEN** the `blank_word` string appears (case-insensitive) within the item's `example` field
