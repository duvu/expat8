# audio-privacy-retention Specification

## Purpose
TBD - created by archiving change add-speaking-foundation. Update Purpose after archive.
## Requirements
### Requirement: Audio remains local-only by default
The mobile app SHALL keep learner speaking audio on the device by default and SHALL NOT upload audio to the backend during phase 0-3 speaking foundation.

#### Scenario: Learner records an attempt
- **WHEN** the learner records a speaking attempt
- **THEN** the app stores the audio locally and syncs only allowed metadata such as attempt ID, prompt ID, duration, retry count, self-rating, and timestamps

#### Scenario: App syncs speaking events
- **WHEN** speaking event sync runs after local recording
- **THEN** the request MUST NOT include raw audio bytes or local audio file paths

### Requirement: Learners can delete local speaking recordings
The mobile app SHALL provide controls to delete local speaking recordings.

#### Scenario: Learner deletes one recording
- **WHEN** the learner deletes a recording for a speaking attempt
- **THEN** the app removes the local audio file while preserving already-synced non-audio metadata unless the learner deletes the entire local attempt history

#### Scenario: Learner deletes all local recordings
- **WHEN** the learner chooses to delete all local speaking recordings
- **THEN** the app removes all local speaking audio files and keeps future speaking practice usable

### Requirement: Local audio retention is bounded
The mobile app SHALL enforce a bounded retention policy for local speaking recordings.

#### Scenario: Recording exceeds retention window
- **WHEN** a local speaking recording is older than the configured retention window
- **THEN** the app removes the local audio file during cleanup without requiring a backend request

### Requirement: Microphone permission is explicit and recoverable
The mobile app SHALL request microphone permission only when the learner starts recording and SHALL handle denial without breaking the learning session.

#### Scenario: Learner denies microphone permission
- **WHEN** the learner denies microphone permission
- **THEN** the app explains that recording requires microphone access, keeps vocabulary learning available, and does not crash or block swipe navigation

