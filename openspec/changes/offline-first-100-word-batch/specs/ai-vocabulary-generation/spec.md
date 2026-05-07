## MODIFIED Requirements

### Requirement: Backend generates vocabulary through LiteLLM
The backend SHALL use LiteLLM as the abstraction layer for AI vocabulary generation and SHALL request 100 words per LLM call.

#### Scenario: Stored inventory is insufficient
- **WHEN** the backend needs new vocabulary and stored suitable inventory is insufficient
- **THEN** the backend requests 100 generated vocabulary items through LiteLLM in a single call

#### Scenario: AI provider changes
- **WHEN** the configured model provider changes behind LiteLLM
- **THEN** the vocabulary generation service continues to use the same internal generation interface with 100-word batch size
