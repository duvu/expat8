## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns new vocabulary items for the mobile app, supporting batch sizes up to 100 items.

#### Scenario: Mobile requests 100 new words
- **WHEN** the mobile app calls the new-word feed endpoint with limit=100
- **THEN** the backend returns up to 100 vocabulary items matching the request parameters

#### Scenario: Existing suitable words are available
- **WHEN** the backend has sufficient stored words available for a 100-word request
- **THEN** the backend returns stored words without calling AI generation

#### Scenario: Stored words are insufficient for a 100-word request
- **WHEN** the backend has fewer than 100 suitable stored words available
- **THEN** the backend triggers LLM generation for a batch of 100, stores results, and returns as many as available
