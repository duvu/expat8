## Purpose
Define how the backend generates, validates, persists, and reuses AI-generated vocabulary for supported language profiles.
## Requirements
### Requirement: Backend generates vocabulary through LiteLLM
The backend SHALL use LiteLLM as the abstraction layer for AI vocabulary generation.

#### Scenario: Stored inventory is insufficient
- **WHEN** the backend needs new vocabulary and stored suitable inventory is insufficient
- **THEN** the backend requests generated vocabulary through LiteLLM

#### Scenario: AI provider changes
- **WHEN** the configured model provider changes behind LiteLLM
- **THEN** the vocabulary generation service continues to use the same internal generation interface

### Requirement: AI output uses a structured schema
The backend SHALL request and process AI vocabulary output as structured JSON with required fields that align to the active language profile and proficiency scale.

#### Scenario: English generation request
- **WHEN** LiteLLM is asked to generate English vocabulary
- **THEN** the backend requests output using CEFR-aligned difficulty values and English profile schema expectations

#### Scenario: Chinese generation request
- **WHEN** LiteLLM is asked to generate Chinese vocabulary
- **THEN** the backend requests output using HSK-aligned difficulty values and Chinese profile pronunciation expectations

### Requirement: Generated vocabulary is validated before persistence
The backend MUST validate AI-generated vocabulary before saving or serving it using language-profile aware pronunciation rules: English items require IPA, while Chinese items require pinyin and do not require IPA.

#### Scenario: Difficulty level is invalid for language profile
- **WHEN** a generated item includes a difficulty value that is not valid for the active language scale
- **THEN** the backend rejects that item

#### Scenario: English item has IPA pronunciation metadata
- **WHEN** a generated English item has non-empty `ipa` and all other required metadata is valid
- **THEN** the backend accepts the item pronunciation metadata

#### Scenario: English item has empty IPA
- **WHEN** a generated English item has empty `ipa`
- **THEN** the backend rejects that item before persistence with an IPA-specific rejection reason

#### Scenario: Chinese item has pinyin and no IPA
- **WHEN** a generated Chinese item has empty `ipa` and valid pinyin in the existing `vietnamese_pronunciation` pronunciation slot
- **THEN** the backend accepts the pronunciation metadata instead of rejecting the item as `missing_ipa`

#### Scenario: Chinese item lacks pinyin
- **WHEN** a generated Chinese item lacks valid pinyin in the existing `vietnamese_pronunciation` pronunciation slot
- **THEN** the backend rejects that item or flags it for regeneration with a pinyin-specific rejection reason

#### Scenario: Chinese item includes IPA but lacks pinyin
- **WHEN** a generated Chinese item includes `ipa` but lacks valid pinyin in the existing `vietnamese_pronunciation` pronunciation slot
- **THEN** the backend rejects that item because Chinese validation is based on pinyin, not IPA

### Requirement: Generated content includes Vietnamese learner support
The backend SHALL generate vocabulary content that remains useful for Vietnamese learners across supported language profiles.

#### Scenario: English item is generated
- **WHEN** the backend accepts an English generated vocabulary item
- **THEN** the item includes Vietnamese meaning, practical pronunciation guidance, a natural example, and Vietnamese example translation

#### Scenario: Chinese item is generated
- **WHEN** the backend accepts a Chinese generated vocabulary item
- **THEN** the item includes Vietnamese meaning and Chinese pronunciation guidance suitable for Vietnamese learners alongside example and translation

### Requirement: Accepted generated words are reused
The backend SHALL persist accepted AI-generated vocabulary items for future requests.

#### Scenario: Generated word passes validation
- **WHEN** a generated word passes validation and deduplication
- **THEN** the backend stores it in the word database

#### Scenario: Later request can use generated inventory
- **WHEN** a later new-word request can be satisfied by stored generated words
- **THEN** the backend can return stored generated words without making a new AI call

