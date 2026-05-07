## MODIFIED Requirements

### Requirement: AI output uses a structured schema
The backend SHALL request and process AI vocabulary output as structured JSON with required fields that align to the active language profile and proficiency scale.

#### Scenario: English generation request
- **WHEN** LiteLLM is asked to generate English vocabulary
- **THEN** the backend requests output using CEFR-aligned difficulty values and English profile schema expectations

#### Scenario: Chinese generation request
- **WHEN** LiteLLM is asked to generate Chinese vocabulary
- **THEN** the backend requests output using HSK-aligned difficulty values and Chinese profile pronunciation expectations

### Requirement: Generated vocabulary is validated before persistence
The backend MUST validate AI-generated vocabulary before saving or serving it using language-profile aware rules.

#### Scenario: Difficulty level is invalid for language profile
- **WHEN** a generated item includes a difficulty value that is not valid for the active language scale
- **THEN** the backend rejects that item

#### Scenario: Chinese pronunciation metadata is insufficient
- **WHEN** a generated Chinese item lacks required pronunciation support defined by the Chinese profile
- **THEN** the backend rejects that item or flags it for regeneration

### Requirement: Generated content includes Vietnamese learner support
The backend SHALL generate vocabulary content that remains useful for Vietnamese learners across supported language profiles.

#### Scenario: English item is generated
- **WHEN** the backend accepts an English generated vocabulary item
- **THEN** the item includes Vietnamese meaning, practical pronunciation guidance, a natural example, and Vietnamese example translation

#### Scenario: Chinese item is generated
- **WHEN** the backend accepts a Chinese generated vocabulary item
- **THEN** the item includes Vietnamese meaning and Chinese pronunciation guidance suitable for Vietnamese learners alongside example and translation
