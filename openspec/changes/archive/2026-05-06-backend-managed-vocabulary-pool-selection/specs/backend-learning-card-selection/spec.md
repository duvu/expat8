## ADDED Requirements

### Requirement: Backend selects learning cards from database state
The backend SHALL return learning cards using stored database vocabulary and learner state without calling AI generation during the request.

#### Scenario: Mobile requests learning cards
- **WHEN** the mobile app requests a learning card batch
- **THEN** the backend selects cards from persisted vocabulary and state tables only

#### Scenario: Stored inventory is insufficient
- **WHEN** the backend cannot satisfy the requested card count from stored database state
- **THEN** the backend returns the available eligible cards and does not call AI generation during the request

### Requirement: Backend targets a 15 percent new and 85 percent review mix
The backend SHALL target 15% new cards and 85% review cards over learning card batches or rolling windows.

#### Scenario: Both new and review pools are available
- **WHEN** the backend selects a card batch and both eligible new and due review words exist
- **THEN** the response targets approximately 15% new cards and 85% review cards

#### Scenario: Requested limit is too small for exact ratio
- **WHEN** the requested card limit cannot exactly represent the configured ratio
- **THEN** the backend applies the closest practical mix and reports the actual mix

#### Scenario: One pool is unavailable
- **WHEN** eligible new cards or due review cards are unavailable
- **THEN** the backend fills from the other eligible pool or returns fewer cards with actual mix metadata

### Requirement: Backend excludes learned and cached words from new-card selection
The backend SHALL exclude words that are completed for the learner or currently cached on the learner's device from new-card selection.

#### Scenario: Word was marked easy
- **WHEN** a word has latest learner state indicating easy-completed or mastered
- **THEN** the backend does not return that word as a new card for the learner

#### Scenario: Word is cached on device
- **WHEN** a word is present in the learner device cache inventory
- **THEN** the backend does not return that word as a duplicate new or replacement card for that device

### Requirement: Backend supports anonymous and signed-in selection
The backend SHALL support card selection for anonymous device-based learners and signed-in user-based learners.

#### Scenario: Anonymous learner requests cards
- **WHEN** a request has a `device_id` and no valid bearer session
- **THEN** the backend selects cards using device-scoped state and cache inventory

#### Scenario: Signed-in learner requests cards
- **WHEN** a request includes a valid bearer session
- **THEN** the backend selects cards using user-scoped learning state while preserving device-scoped cache inventory

### Requirement: Card responses expose selection metadata
The backend SHALL include enough metadata in batch card responses to verify target mix and source decisions.

#### Scenario: Card batch is returned
- **WHEN** the backend returns a learning card batch
- **THEN** the response includes target mix, actual mix, and per-card card type or selection reason
