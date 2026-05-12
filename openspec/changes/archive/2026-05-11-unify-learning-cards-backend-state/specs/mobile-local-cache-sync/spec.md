## MODIFIED Requirements

### Requirement: New-word requests fall back to local storage
The mobile app SHALL use local fallback when the unified backend learning-card request fails, times out after 5 seconds, or the device is offline, and SHALL emit diagnostic logs for request attempts, fallback decisions, and fallback outcomes.

#### Scenario: Backend returns within timeout
- **WHEN** the app requests new learning cards and the backend returns a valid `/v1/learning/cards` response within 5 seconds
- **THEN** the app saves the returned words locally, displays an eligible local card, and records a success log event for the remote fetch path

#### Scenario: Backend request times out
- **WHEN** the app requests new learning cards and the backend does not return within 5 seconds
- **THEN** the app queries local eligible new words, displays one if available, and records timeout and fallback-attempt log events

#### Scenario: No local new word is available
- **WHEN** backend fallback is required and no eligible local new word exists
- **THEN** the app displays an eligible review word if one is available and records a fallback-result log event indicating source selection

#### Scenario: Legacy per-word request is not used
- **WHEN** the app needs more new words
- **THEN** the app does not call `/v1/words/next` and does not send `exclude_server_word_id` values

## ADDED Requirements

### Requirement: Mobile uses unified backend card refill
The mobile app SHALL refill local new-word cache by requesting 10 backend-selected new words from `/v1/learning/cards`.

#### Scenario: Local new-word cache is low
- **WHEN** the local cache needs more new words
- **THEN** the app requests `/v1/learning/cards` with `device_id`, target language, and limit 10

#### Scenario: Backend returns a partial batch
- **WHEN** the backend returns fewer than 10 new words
- **THEN** the app persists the returned words and continues using local fallback behavior for any remaining shortage

### Requirement: Mobile maintains anonymous learner identifier
The mobile app SHALL maintain a stable anonymous learner identifier in the form `anonymous_<uuid-v4>` when no user session exists.

#### Scenario: Anonymous identifier is missing
- **WHEN** the app starts and no local anonymous identifier exists
- **THEN** the app generates and stores a new `anonymous_<uuid-v4>` identifier

#### Scenario: Learning request is anonymous
- **WHEN** the app requests backend learning cards without a signed-in user session
- **THEN** the app sends the stable anonymous identifier as `device_id`

#### Scenario: User signs in
- **WHEN** the app requests backend learning cards with a signed-in user session
- **THEN** the app sends bearer authorization and still includes the stable `device_id` for device and cache context
