## MODIFIED Requirements

### Requirement: Backend generates vocabulary through LiteLLM
The backend SHALL use LiteLLM as the abstraction layer for asynchronous AI vocabulary generation and SHALL NOT call LiteLLM while handling mobile learning-card requests.

#### Scenario: Stored inventory is insufficient
- **WHEN** the backend scheduler determines that stored suitable inventory is insufficient
- **THEN** the backend requests generated vocabulary through LiteLLM outside the mobile request path

#### Scenario: Mobile request finds insufficient inventory
- **WHEN** a mobile word or card request cannot be fully satisfied from stored inventory
- **THEN** the backend returns the available database-backed result without requesting generated vocabulary through LiteLLM

#### Scenario: AI provider changes
- **WHEN** the configured model provider changes behind LiteLLM
- **THEN** the vocabulary generation service continues to use the same internal generation interface

## ADDED Requirements

### Requirement: AI generation results are decoupled from user latency
The backend SHALL persist accepted AI-generated vocabulary before it can be selected for mobile users.

#### Scenario: Scheduler accepts generated words
- **WHEN** the scheduler accepts generated vocabulary items
- **THEN** the backend persists those words before any mobile response can include them

#### Scenario: Scheduler rejects generated words
- **WHEN** generated vocabulary fails validation or deduplication
- **THEN** the backend does not serve those rejected items to mobile clients
