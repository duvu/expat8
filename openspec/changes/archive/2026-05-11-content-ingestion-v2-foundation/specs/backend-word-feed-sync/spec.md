## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL serve new-word and card inventory responses from persisted approved/processed vocabulary scoped by language and proficiency policy, and SHALL NOT generate vocabulary inline during feed requests.

#### Scenario: Mobile requests a new word
- **WHEN** the mobile app calls the new-word or learning-card feed endpoint with language and learner context
- **THEN** the backend returns stored eligible vocabulary items filtered by resolved proficiency policy and assignment exclusions

#### Scenario: Stored words are unavailable
- **WHEN** the backend has insufficient eligible stored words for the request
- **THEN** the backend returns fewer items or configured fallback items without triggering LLM generation in the request path
