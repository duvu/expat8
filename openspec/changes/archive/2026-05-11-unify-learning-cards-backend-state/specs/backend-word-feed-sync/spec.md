## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide `/v1/learning/cards` as the single API endpoint used by mobile to load backend-selected new vocabulary cards.

#### Scenario: Mobile requests ten new words
- **WHEN** the mobile app requests learning cards with `device_id`, target language, and a limit of 10
- **THEN** the backend returns up to 10 new vocabulary items selected from backend state

#### Scenario: Request omits client-side exclusions
- **WHEN** the mobile app requests learning cards
- **THEN** the request does not include `exclude_server_word_id`, current word ID, or any other client-provided word exclusion list

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a learning-card request
- **THEN** the backend returns stored words without calling AI generation

#### Scenario: Legacy new-word endpoint is removed
- **WHEN** a client calls `/v1/words/next`
- **THEN** the backend does not expose the legacy route as a supported API

### Requirement: Backend data model supports future authentication
The backend SHALL support anonymous device-based usage through `anonymous_<uuid-v4>` identifiers while preserving signed-in user-based personalization.

#### Scenario: Study event is received before authentication exists
- **WHEN** the backend receives a study event without a user identity
- **THEN** the backend associates the event with the provided `anonymous_<uuid-v4>` device identifier

#### Scenario: User identity is introduced later
- **WHEN** authenticated requests include a valid bearer session and `device_id`
- **THEN** the backend associates new word state and study events with the signed-in user while retaining the submitted `device_id` for device and cache context

#### Scenario: Signed-in learner has anonymous history
- **WHEN** a signed-in request includes a `device_id` that has anonymous learning state
- **THEN** backend new-card selection excludes words already studied or actively cached under that anonymous device context
