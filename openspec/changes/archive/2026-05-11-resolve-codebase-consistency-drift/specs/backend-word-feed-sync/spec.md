## MODIFIED Requirements

### Requirement: Backend provides new vocabulary feed
The backend SHALL provide `POST /v1/learning/cards` as the single API endpoint that returns backend-selected new vocabulary cards for the mobile app. The backend MUST NOT expose `/v1/words/next` as a supported compatibility route.

#### Scenario: Mobile requests learning cards
- **WHEN** the mobile app calls `POST /v1/learning/cards` with a valid `device_id`, target language, limit, and `card_mode: "new"`
- **THEN** the backend returns vocabulary card items matching backend-owned learner state and persists returned word IDs as active cache or claim inventory

#### Scenario: Existing suitable words are available
- **WHEN** the backend has suitable stored words available for a learning-card request
- **THEN** the backend can return stored words without calling AI generation

#### Scenario: Unsupported card mode is requested
- **WHEN** a client calls `POST /v1/learning/cards` with a `card_mode` value other than `new`
- **THEN** the backend rejects the request with `400 { "error": "bad_request" }`

#### Scenario: Client sends word exclusions
- **WHEN** a client calls `POST /v1/learning/cards` with client-side word exclusion fields
- **THEN** the backend rejects the request with `400 { "error": "bad_request" }`

#### Scenario: Legacy new-word route is called
- **WHEN** a client calls `/v1/words/next`
- **THEN** the backend treats the route as unsupported and does not execute word selection logic

### Requirement: Backend accepts idempotent study event sync
The backend SHALL provide an API endpoint that accepts study events from mobile clients, treats `client_event_id` as an idempotency key, and returns a stable response shape containing accepted IDs, rejected events, and the current proficiency state.

#### Scenario: New study event is synced
- **WHEN** the mobile app sends a study event with a new `client_event_id`
- **THEN** the backend stores the event and returns it as accepted with the resulting proficiency state

#### Scenario: Duplicate study event is retried
- **WHEN** the mobile app resends a study event with an already accepted `client_event_id`
- **THEN** the backend does not create a duplicate event and returns a successful idempotent result with the same response shape as a new accepted event

#### Scenario: Empty sync batch is received
- **WHEN** the mobile app sends a sync request with an empty `events` array
- **THEN** the backend returns no accepted IDs, no rejected events, and the current proficiency state

#### Scenario: All sync events are rejected
- **WHEN** every event in a sync batch is rejected for validation reasons
- **THEN** the backend returns the rejected events and the current proficiency state without omitting the `proficiency` field

### Requirement: Backend supports recent-word bootstrap
The backend SHALL provide a read-only API endpoint that returns recent vocabulary items for bootstrapping or restoring a local mobile cache using only contract-backed bootstrap parameters.

#### Scenario: Mobile requests recent words
- **WHEN** the mobile app requests recent words with `limit` and `target_language`
- **THEN** the backend returns no more than 1000 recent vocabulary items matching the target language

#### Scenario: Mobile needs learner-specific duplicate avoidance
- **WHEN** mobile needs backend-owned duplicate avoidance, device context, or cache claim behavior
- **THEN** mobile uses `/v1/learning/cards` and `/v1/user-word-cache` instead of adding learner-specific parameters to `/v1/words/recent`

#### Scenario: Current contract is documented
- **WHEN** `contracts/api.md` documents `/v1/words/recent`
- **THEN** it documents only the parameters the backend implements for recent-word bootstrap
