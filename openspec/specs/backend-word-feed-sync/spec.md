## Purpose
Define how the backend serves new and recent vocabulary items to mobile clients for local cache bootstrapping and refill.
## Requirements
### Requirement: Backend provides new vocabulary feed
The backend SHALL serve new-word and card inventory responses from persisted approved/processed vocabulary scoped by language and proficiency policy, and SHALL NOT generate vocabulary inline during feed requests.

#### Scenario: Mobile requests a new word
- **WHEN** the mobile app calls the new-word or learning-card feed endpoint with language and learner context
- **THEN** the backend returns stored eligible vocabulary items filtered by resolved proficiency policy and assignment exclusions

#### Scenario: Stored words are unavailable
- **WHEN** the backend has insufficient eligible stored words for the request
- **THEN** the backend returns fewer items or configured fallback items without triggering LLM generation in the request path

### Requirement: Backend stores vocabulary records
The backend SHALL persist generated or accepted vocabulary items with the fields required by the mobile learning card.

#### Scenario: Word is persisted
- **WHEN** a vocabulary item is accepted for use
- **THEN** the backend stores its term, normalized term, language, Vietnamese meaning, part of speech, IPA, Vietnamese-friendly pronunciation, example, example translation, difficulty, topics, generation source, and timestamps

#### Scenario: Duplicate word is detected
- **WHEN** a vocabulary item has the same normalized term and language as an existing word
- **THEN** the backend prevents duplicate vocabulary storage

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

### Requirement: Backend provides scale-native proficiency lookup
The backend SHALL return proficiency using language-native scale semantics when clients request proficiency state.

#### Scenario: Proficiency lookup for English
- **WHEN** the client requests proficiency for English
- **THEN** the backend returns proficiency with `scale=cefr` and a CEFR level value

#### Scenario: Proficiency lookup for Chinese
- **WHEN** the client requests proficiency for Chinese
- **THEN** the backend returns proficiency with `scale=hsk` and an HSK level value

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

