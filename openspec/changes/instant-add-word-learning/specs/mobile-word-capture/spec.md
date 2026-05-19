## MODIFIED Requirements

### Requirement: Learner can open a manual word-capture flow from the mobile app
The mobile app SHALL provide a learner-facing entry point from the main learning experience for capturing a word or short expression manually, defaulting the submission language to the current active learning language.

#### Scenario: Learner opens capture flow from vocabulary screen
- **WHEN** the learner is on the main vocabulary experience and chooses the word-capture action
- **THEN** the app opens a manual capture form without interrupting the existing learning session state

#### Scenario: Capture form defaults to active learning language
- **WHEN** the learner opens the capture form while studying a specific learning language
- **THEN** the form preselects that language and allows choosing only supported learning languages

### Requirement: Mobile stores captured words locally before backend confirmation
The mobile app SHALL preserve learner-entered text locally while the immediate add-word request is in flight, but normal successful operation SHALL no longer depend on a queued offline submission lifecycle.

#### Scenario: Learner submits while request is in flight
- **WHEN** the learner confirms an add-word submission and the backend request has not completed yet
- **THEN** the app keeps the typed term visible in the current local UI state until the request resolves

#### Scenario: Learner is offline before submission succeeds
- **WHEN** the learner confirms an add-word submission while the device is offline or the request cannot complete
- **THEN** the app shows a visible submission failure and does not represent the term as queued for later learner-visible processing

### Requirement: Mobile synchronizes submission status with the backend
The mobile app SHALL treat the normal add-word request as an immediate terminal response flow and SHALL not require background polling to make the learner's new word ready.

#### Scenario: Add-word request succeeds immediately
- **WHEN** the app submits a learner-entered word and the backend returns a ready response
- **THEN** the app updates local state from that single response and does not enqueue status polling for the normal flow

#### Scenario: Add-word request fails immediately
- **WHEN** the app submits a learner-entered word and the backend returns an error response
- **THEN** the app shows the error outcome directly to the learner instead of showing queued or processing status cards

### Requirement: Ready submissions become normal local learning words
The mobile app SHALL import an immediately resolved add-word response into the same local vocabulary store used by standard learning-card refill, rather than a separate custom word store.

#### Scenario: Add-word resolves to a new generated word
- **WHEN** the add-word request returns a ready response with a generated resolved word
- **THEN** the app upserts that word into local vocabulary storage during the same submission flow

#### Scenario: Add-word resolves to an existing stored word
- **WHEN** the add-word request returns a ready response for an existing canonical word
- **THEN** the app imports that canonical word locally without creating a duplicate local word

### Requirement: Learner can see submission outcomes
The mobile app SHALL show immediate learner feedback for successful or failed add-word resolution, and the normal add-word list SHALL reflect terminal outcomes instead of long-running queued or processing states.

#### Scenario: Add-word succeeds immediately
- **WHEN** the learner submits a word and the backend returns a ready resolved word
- **THEN** the app shows immediate success feedback describing whether the word already existed or was generated now

#### Scenario: Add-word fails immediately
- **WHEN** the learner submits a word and the backend cannot resolve it in-request
- **THEN** the app shows a failure message for that attempt without leaving the learner in an indeterminate processing state
