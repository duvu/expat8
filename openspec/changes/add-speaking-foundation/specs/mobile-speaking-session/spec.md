## ADDED Requirements

### Requirement: Mobile supports local speaking practice from vocabulary cards
The mobile app SHALL allow learners to open a speaking practice panel from an eligible vocabulary card, view a target sentence and Vietnamese hint, record themselves locally, play back the recording, retry the prompt, and self-rate the attempt.

#### Scenario: Learner records a speaking prompt
- **WHEN** a learner opens a speaking prompt from a vocabulary card and grants microphone permission
- **THEN** the app records the attempt to local device storage and associates it with a local attempt ID, prompt ID, word sense or word ID, duration, retry count, and occurred-at timestamp

#### Scenario: Learner plays back own recording
- **WHEN** a learner has recorded a speaking attempt for the current prompt
- **THEN** the app allows the learner to play back that local recording without requiring a network request

#### Scenario: Learner retries a prompt
- **WHEN** a learner records the same prompt again before leaving the speaking panel
- **THEN** the app treats the new recording as a retry for the same prompt and increments the retry count for the attempt metadata

#### Scenario: Learner self-rates a speaking attempt
- **WHEN** a learner chooses `clear`, `hesitated`, or `could_not_say` after recording
- **THEN** the app stores that self-rating with the speaking attempt metadata and queues the corresponding speaking study event for sync

### Requirement: Mobile speaking practice works offline
The mobile app SHALL allow speaking practice to continue offline when the vocabulary card and prompt are already cached locally.

#### Scenario: Offline recording is saved locally
- **WHEN** the learner records and self-rates a cached speaking prompt while offline
- **THEN** the app saves the audio locally, saves the attempt metadata locally, queues speaking events for later sync, and does not block the learner from continuing the session

#### Scenario: Prompt is missing
- **WHEN** a vocabulary card has no approved speaking prompt
- **THEN** the app may use the card's example sentence as a fallback speaking target or hide the speaking entry point for that card

### Requirement: Mobile provides a short speaking drill
The mobile app SHALL provide a short speaking drill that selects a small set of cached speaking prompts and guides the learner through listen, record, self-rate, and summary steps.

#### Scenario: Learner completes a speaking drill
- **WHEN** a learner starts a 3-minute speaking drill and enough cached prompts are available
- **THEN** the app selects up to five prompts, tracks progress through each prompt, and displays an end summary with spoken sentence count, retry count, self-rating counts, and approximate speaking time

#### Scenario: Drill has insufficient prompts
- **WHEN** fewer than five cached speaking prompts are available
- **THEN** the app starts the drill with available prompts or explains that more prompts are needed without failing the learning session

### Requirement: Speaking practice avoids harsh scoring in phase 0-3
The mobile app SHALL present speaking practice as private self-practice and SHALL NOT show AI pronunciation scores, pass/fail grades, or harsh corrective language in this phase.

#### Scenario: Attempt summary is encouraging
- **WHEN** a learner completes a speaking attempt or drill
- **THEN** the app summarizes what the learner practiced using encouraging copy such as spoken sentence count, speaking time, and retry effort
