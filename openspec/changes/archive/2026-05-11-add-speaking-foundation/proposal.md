## Why

Expat8 currently helps Vietnamese learners build vocabulary through offline-first flashcards and content-derived word senses, but it does not yet create a measurable habit of speaking English out loud. The next 0-3 month product step is to add a low-pressure speaking foundation so learners can listen, repeat, hear themselves, self-rate, and build confidence before AI pronunciation scoring or live conversation features are introduced.

## What Changes

- Add an optional speaking mode to vocabulary cards where learners can listen to a sample sentence, record themselves locally, play back their attempt, retry, and self-rate the attempt as `clear`, `hesitated`, or `could_not_say`.
- Add a short 3-minute speaking drill that selects a small set of cached prompts and summarizes spoken sentences, retries, and self-ratings.
- Add speaking prompt content fields for target text, Vietnamese hint, target phrase, pronunciation tip, common Vietnamese learner mistake, difficulty, topic, and approval status.
- Extend study-event sync to accept speaking behavior events and typed metadata without uploading audio.
- Keep learner audio local-only by default with retention and deletion controls.
- Extend the dashboard review workflow so admins can review and approve speaking prompts alongside vocabulary quality work.
- Add basic weekly speaking metrics for spoken sentence count, retry count, self-ratings, and streak-style reporting.
- No AI pronunciation scoring, speech-to-text requirement, public voice community, or realtime AI conversation is included in this change.

## Capabilities

### New Capabilities

- `mobile-speaking-session`: Mobile local speaking card and 3-minute drill behavior, including local record/playback, retries, self-rating, offline operation, and non-blocking integration with the existing swipe session.
- `speaking-study-events`: Backend/mobile contract for speaking event types, idempotent metadata sync, weekly speaking summaries, and no-audio payload constraints.
- `speaking-prompt-review`: Content and dashboard review workflow for speaking prompts attached to vocabulary word senses or article terms.
- `audio-privacy-retention`: Local-only audio retention, deletion, and privacy requirements for phase 0-3.

### Modified Capabilities

- `mobile-learning-session`: The learning session gains optional speaking entry points while preserving local-first swipe behavior and non-blocking card selection.
- `study-events-api`: Study event sync accepts fixed speaking event types and typed metadata without breaking existing memory rating events.
- `expat8-dashboard`: The dashboard can display, edit, and approve speaking prompt fields used by mobile speaking sessions.

## Impact

- Mobile app: audio recording/playback dependency, microphone permission flow, local audio file storage, local speaking attempt metadata, speaking card UI, 3-minute drill UI, and local outbox events.
- Backend API: study event validation and persistence for speaking events, summary query support, and possible schema changes for speaking prompt metadata.
- Database: prompt-related fields or a new `speaking_prompts` table; speaking event metadata storage and summary indexes may be needed.
- Dashboard: vocabulary/article review screens gain prompt editing and prompt approval controls.
- Contracts/docs: update API contract and product docs to define speaking event types, prompt payloads, local-only audio constraints, and weekly summary behavior.
- Dependencies: likely Flutter audio recording/playback plugin and platform microphone permission declarations.
