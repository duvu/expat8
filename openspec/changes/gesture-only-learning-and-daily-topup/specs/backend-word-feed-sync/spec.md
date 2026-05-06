## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide an API endpoint that returns vocabulary items for mobile learning flows, including batch retrieval for local top-up requests.

#### Scenario: Mobile requests top-up batch
- **WHEN** the mobile app requests learning cards with a top-up limit of 100
- **THEN** the backend returns up to 100 vocabulary items matching request parameters and availability constraints

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a learning-card request
- **THEN** the backend may return stored words without calling AI generation

### Requirement: Backend supports recent-word bootstrap
The backend SHALL support mobile local-cache bootstrap and refill behavior by returning bounded recent vocabulary datasets compatible with 1000-word local cache policy.

#### Scenario: Mobile requests recent words
- **WHEN** the mobile app requests recent words for cache bootstrap with limit up to 1000
- **THEN** the backend returns no more than 1000 recent vocabulary items

#### Scenario: Mobile requests incremental refill
- **WHEN** the mobile app requests incremental refill with limit 100
- **THEN** the backend returns a bounded set that can be merged locally without requiring server-side session state
