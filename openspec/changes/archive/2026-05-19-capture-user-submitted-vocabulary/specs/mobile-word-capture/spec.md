## ADDED Requirements

### Requirement: Learner can open a manual word-capture flow from the mobile app
The mobile app SHALL provide a learner-facing entry point from the main learning experience for capturing a word or short expression manually, defaulting the submission language to the current active learning language.

#### Scenario: Learner opens capture flow from vocabulary screen
- **WHEN** the learner is on the main vocabulary experience and chooses the word-capture action
- **THEN** the app opens a manual capture form without interrupting the existing learning session state

#### Scenario: Capture form defaults to active learning language
- **WHEN** the learner opens the capture form while studying a specific learning language
- **THEN** the form preselects that language and allows choosing only supported learning languages

### Requirement: Mobile stores captured words locally before backend confirmation
The mobile app SHALL persist manually entered submissions locally so the learner's input survives app restarts and temporary offline/network failure.

#### Scenario: Learner submits while offline
- **WHEN** the learner enters a term and confirms submission while the device is offline or the backend request cannot complete
- **THEN** the app stores the submission locally with a queued/pending-sync status and schedules it for retry

#### Scenario: Learner restarts app with pending submissions
- **WHEN** the app starts and there are locally stored manual submissions that are not terminal
- **THEN** the app reloads those submissions and continues their sync/status lifecycle without losing the typed term

### Requirement: Mobile synchronizes submission status with the backend
The mobile app SHALL upload queued submissions to the backend using the existing signed request model and SHALL refresh remote status for submissions that are pending processing.

#### Scenario: Queued submission is uploaded successfully
- **WHEN** the app syncs a locally queued manual submission and the backend accepts it
- **THEN** the app stores the returned backend submission identifier and updates the local status to the backend-reported non-terminal or terminal state

#### Scenario: Remote submission is still processing
- **WHEN** the app refreshes a submission whose backend status is pending or processing
- **THEN** the app preserves the submission locally and shows that it is still being prepared for learning

### Requirement: Ready submissions become normal local learning words
The mobile app SHALL import backend-resolved submissions into the same local vocabulary store used by standard learning-card refill, rather than a separate custom word store.

#### Scenario: Submission resolves to a new enriched word
- **WHEN** a submission status refresh returns a ready submission with a resolved word payload
- **THEN** the app upserts that word into local vocabulary storage and marks the submission as ready/imported for study

#### Scenario: Submission resolves to an existing stored word
- **WHEN** the backend reports that the submitted term matches an already stored canonical word and returns that resolved word payload
- **THEN** the app imports the canonical word locally and surfaces that the submission is ready without creating a duplicate local word

### Requirement: Learner can see submission outcomes
The mobile app SHALL show the learner whether each manual submission is pending, processing, ready, or failed, including a failure reason when the backend cannot enrich the term.

#### Scenario: Submission fails enrichment
- **WHEN** the backend marks a submitted term as failed
- **THEN** the mobile app shows the failed status and the backend-provided failure reason without silently dropping the submission

#### Scenario: Submission list contains mixed states
- **WHEN** the learner opens the captured-word list and some submissions are queued, processing, ready, and failed
- **THEN** the app renders each submission with its current state and keeps ready items distinct from still-pending ones
