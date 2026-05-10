## ADDED Requirements

### Requirement: Mobile provides a 3-minute speaking drill entry point

The mobile app SHALL provide a dedicated speaking drill mode accessible from the home screen and/or learning session end screen. The drill SHALL select 5 speaking prompts and guide the learner through each one.

#### Scenario: Drill entry point visible when feature flag enabled
- **WHEN** `SPEAKING_FOUNDATION_ENABLED` is true and user is on home or session end screen
- **THEN** a drill entry point (button or card) is visible inviting user to start a speaking drill

#### Scenario: Drill selects 5 prompts from local cache
- **WHEN** user starts a drill
- **THEN** app selects up to 5 speaking prompts from ObjectBox, prioritizing words with `due_review_at <= now()` then `last_learned_at DESC`

#### Scenario: Drill falls back to recently learned words when prompts are scarce
- **WHEN** fewer than 5 prompts are available in local cache
- **THEN** app fills remaining slots from recently learned word senses (using example sentence as fallback prompt)

### Requirement: Each drill card follows the speak–hear–rate loop

For each prompt in the drill, the app SHALL present a speak–hear–self-rate loop before advancing to the next prompt.

#### Scenario: Learner records audio for a prompt
- **WHEN** user holds record button on a drill card
- **THEN** app records audio locally, stores file keyed by `attempt_id`, and enables playback button

#### Scenario: Learner plays back their own recording
- **WHEN** user taps play button after recording
- **THEN** app plays back the locally stored audio file for that attempt

#### Scenario: Learner self-rates after recording
- **WHEN** user has recorded and optionally played back
- **THEN** app shows three rating options: "Clear", "Hesitated", "Could not say it"

#### Scenario: Retry increments retry count
- **WHEN** user taps "Try again" on the same prompt
- **THEN** `retry_count` increments, a new `attempt_id` is generated, previous audio is discarded, and new recording begins

### Requirement: Drill emits speaking study events for each action

The mobile app SHALL emit the correct study events during drill execution so that backend can compute analytics.

#### Scenario: Prompt viewed event emitted
- **WHEN** a drill card becomes active (visible to user)
- **THEN** app queues `speaking_prompt_viewed` event with `prompt_id` and `word_sense_id`

#### Scenario: Sample played event emitted
- **WHEN** user taps the "Listen" button on a drill card
- **THEN** app queues `speaking_sample_played` event with `prompt_id`

#### Scenario: Recording event emitted
- **WHEN** user completes a recording
- **THEN** app queues `speaking_recorded` event with `attempt_id`, `prompt_id`, `duration_ms`, `retry_count`

#### Scenario: Self-rating event emitted
- **WHEN** user selects a self-rating
- **THEN** app queues the corresponding event (`speaking_self_rated_clear`, `speaking_self_rated_hesitated`, or `speaking_self_rated_could_not_say`) with `attempt_id`

### Requirement: Drill shows encouraging summary after completion

After all 5 prompts are completed (or user skips remaining), the app SHALL show a summary screen.

#### Scenario: Summary displays positive metrics
- **WHEN** drill ends (all prompts done or user taps "Finish")
- **THEN** summary screen shows: number of sentences spoken, total duration, retry count, and an encouraging message (e.g., "Bạn đã nói 5 câu hôm nay.")

#### Scenario: Drill completion event emitted
- **WHEN** summary screen is shown
- **THEN** app queues `speaking_drill_completed` event with `prompts_attempted`, `prompts_completed`, `total_duration_ms`

### Requirement: Drill operates fully offline

The drill SHALL function without network connectivity if prompts are already cached locally.

#### Scenario: Drill works with no network
- **WHEN** device is offline and local ObjectBox has at least 1 speaking prompt
- **THEN** user can complete a full drill; all events are queued in outbox for later sync

#### Scenario: Missing microphone permission handled gracefully
- **WHEN** user starts recording but microphone permission is denied
- **THEN** app shows a non-alarming explanation dialog and allows user to skip or go to settings; drill does NOT crash
