## ADDED Requirements

### Requirement: Learning card source decisions use distinct diagnostic events
The mobile app SHALL log learning-card source decisions with event names and context fields that distinguish local cache hits, backend refill success, empty refill results, backend errors, and fallback misses.

#### Scenario: Local new word is selected without backend refill
- **WHEN** the app serves a new-word card from an existing local cache entry
- **THEN** the app records a local-hit diagnostic event without labeling the result as a backend success

#### Scenario: Backend refill supplies local words
- **WHEN** the app calls backend-managed refill and stores returned cards before selecting one locally
- **THEN** the app records a backend-refill success event and a card-source event that indicates the selected card came after refill

#### Scenario: Backend refill returns no usable new words
- **WHEN** backend-managed refill completes but no local new word is available afterward
- **THEN** the app records an empty-refill or local-miss diagnostic event with no always-false fallback fields

#### Scenario: Backend request fails and local fallback is used
- **WHEN** a backend request fails, times out, or is unavailable and a local card is selected
- **THEN** the app records the backend error and local fallback outcome with sanitized context
