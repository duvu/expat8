## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns exactly `limit` vocabulary items (default 10, maximum 10) for the mobile app, generating AI vocabulary to fill the response when stored words are insufficient.

#### Scenario: Mobile requests a new word batch
- **WHEN** the mobile app calls `POST /v1/learning/cards` with `card_mode: new` and `limit: 10`
- **THEN** the backend returns exactly 10 vocabulary items in the `items` array

#### Scenario: Stored words are sufficient
- **WHEN** the backend has 10 or more stored eligible words for the request parameters
- **THEN** the backend returns 10 stored words without calling AI generation

#### Scenario: Stored words are insufficient
- **WHEN** the backend has fewer than `limit` stored eligible words for the request parameters
- **THEN** the backend generates the shortfall via AI and returns exactly `limit` words in a single response

#### Scenario: AI generation partially fills the shortfall
- **WHEN** AI generation returns fewer words than needed to reach `limit`
- **THEN** the backend returns however many words it has (stored + generated), which may be fewer than `limit`, and the response `actual_mix.new` reflects the real count
