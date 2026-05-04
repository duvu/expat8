## ADDED Requirements

### Requirement: Backend generates vocabulary through LiteLLM
The backend SHALL use LiteLLM as the abstraction layer for AI vocabulary generation.

#### Scenario: Stored inventory is insufficient
- **WHEN** the backend needs new vocabulary and stored suitable inventory is insufficient
- **THEN** the backend requests generated vocabulary through LiteLLM

#### Scenario: AI provider changes
- **WHEN** the configured model provider changes behind LiteLLM
- **THEN** the vocabulary generation service continues to use the same internal generation interface

### Requirement: AI output uses a structured schema
The backend SHALL request and process AI vocabulary output as structured JSON with required vocabulary fields.

#### Scenario: AI returns valid structured output
- **WHEN** LiteLLM returns JSON containing all required vocabulary fields
- **THEN** the backend parses the response into vocabulary items

#### Scenario: AI returns non-JSON output
- **WHEN** LiteLLM returns output that cannot be parsed as valid JSON
- **THEN** the backend rejects the output and does not persist it as vocabulary

### Requirement: Generated vocabulary is validated before persistence
The backend MUST validate AI-generated vocabulary before saving or serving it.

#### Scenario: Required field is missing
- **WHEN** a generated vocabulary item lacks a required field
- **THEN** the backend rejects that item

#### Scenario: IPA is empty
- **WHEN** a generated vocabulary item has an empty IPA value
- **THEN** the backend rejects that item

#### Scenario: Example does not match the term
- **WHEN** a generated vocabulary item has an example that is unrelated to the term
- **THEN** the backend rejects that item or flags it for regeneration

### Requirement: Generated content includes Vietnamese learner support
The backend SHALL generate vocabulary content that is useful for Vietnamese learners.

#### Scenario: Vocabulary item is generated
- **WHEN** the backend accepts a generated vocabulary item
- **THEN** the item includes Vietnamese meaning, Vietnamese-friendly pronunciation, IPA, a natural example, and Vietnamese example translation

#### Scenario: Vietnamese-friendly pronunciation is generated
- **WHEN** the backend generates Vietnamese-friendly pronunciation
- **THEN** the pronunciation is stored as a practical reading aid alongside IPA, not as a replacement for IPA

### Requirement: Accepted generated words are reused
The backend SHALL persist accepted AI-generated vocabulary items for future requests.

#### Scenario: Generated word passes validation
- **WHEN** a generated word passes validation and deduplication
- **THEN** the backend stores it in the word database

#### Scenario: Later request can use generated inventory
- **WHEN** a later new-word request can be satisfied by stored generated words
- **THEN** the backend can return stored generated words without making a new AI call
