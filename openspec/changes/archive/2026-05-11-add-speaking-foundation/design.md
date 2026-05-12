## Context

Expat8's current learning loop is vocabulary-first: the mobile app displays locally cached cards, records ratings through study events, syncs them to the backend, and receives adaptive proficiency updates. The backend and dashboard have started moving toward content-derived vocabulary through article ingestion, `word_senses`, `article_terms`, and dashboard review.

The phase 0-3 speaking foundation turns this vocabulary base into a low-pressure speaking loop. Learners should be able to open a speaking prompt from a vocabulary card, listen to or read a sample sentence, record themselves locally, play back their own recording, retry, self-rate, and continue learning without blocking the swipe session or requiring network access.

This change crosses mobile, backend, database, dashboard, and contract surfaces. It also introduces microphone permission and local audio privacy concerns, so it needs explicit design decisions before implementation.

## Goals / Non-Goals

**Goals:**

- Add a mobile speaking card flow with local record/playback, retry, and self-rating.
- Add a 3-minute drill that selects a small set of cached speaking prompts and produces a positive completion summary.
- Add reviewed speaking prompt content linked to vocabulary word senses or article terms.
- Sync speaking behavior metadata to the backend without uploading audio.
- Preserve existing offline-first swipe behavior and memory-rating study events.
- Provide weekly speaking summary metrics that can measure adoption of the speaking loop.
- Keep audio private by default through local-only storage, retention, and deletion controls.

**Non-Goals:**

- No AI pronunciation scoring in this change.
- No speech-to-text requirement.
- No realtime AI conversation or AI role-play coach.
- No human coach review, public voice sharing, or community features.
- No monetization/paywall work.
- No expansion of speaking support beyond English in this phase.

## Decisions

### Decision 1: Keep audio local-only and sync metadata only

Learner audio SHALL remain on the device by default. The backend receives speaking metadata such as prompt ID, duration, retry count, self-rating, and timestamps, but no audio file or local file path.

Alternatives considered:

- Upload audio immediately for later AI scoring. Rejected for phase 0-3 because it adds privacy, storage, bandwidth, and trust risks before the product has proven that learners will record regularly.
- Do not store audio at all. Rejected because playback of the learner's own voice is central to reducing fear of speaking.

Rationale:

- Local-only audio lowers privacy risk and cost.
- Metadata is enough to measure first recording conversion, spoken sentences, retries, and self-ratings.
- The later AI feedback phase can introduce explicit opt-in upload and retention policies after this loop is validated.

### Decision 2: Add a dedicated `speaking_prompts` content model

Speaking prompts should be separate records linked to `word_senses` and optionally `article_terms`. Each prompt includes `target_text`, `vi_hint`, `target_phrase`, `pronunciation_tip_vi`, `common_mistake_vi`, `difficulty`, `topic`, `status`, timestamps, and review metadata.

Alternatives considered:

- Embed prompt fields directly on `word_senses`. Rejected because a word sense may need multiple prompts over time and because dashboard review status is clearer as a separate workflow.
- Reuse existing example sentence fields only. Rejected because existing examples may be too long, too written, or not suitable as speaking prompts.

Rationale:

- Dedicated prompts support curated quality for the first 50-200 prompts.
- Prompts can evolve independently of vocabulary definitions.
- Dashboard can review prompt quality without overloading vocabulary review fields.

### Decision 3: Extend study-event sync as a union, but store speaking events separately

The existing study event endpoints currently model memory ratings and feed proficiency/SRS state. Speaking events should reuse the signed sync path and local outbox behavior, but backend persistence should avoid forcing non-rating data into `study_events.rating`.

The backend should accept a discriminated event payload:

- Rating events keep the existing fields and persistence path.
- Speaking events include `event_type` values such as `speaking_recorded`, `speaking_retried`, and `speaking_self_rated_clear` plus typed `speaking` metadata.

Speaking events should persist in a new table such as `speaking_events`, keyed by client event ID for idempotency.

Alternatives considered:

- Make `study_events.rating` nullable and store all speaking events in the existing table. Rejected because the existing table drives proficiency and word-state updates; mixing non-rating events raises regression risk.
- Add a separate `/v1/speaking/attempts` API now. Rejected for phase 0-3 because it duplicates sync/outbox concerns before audio upload or AI scoring exists.

Rationale:

- Mobile can keep one outbox/sync concept for learner activity.
- Backend can keep proficiency logic isolated to rating events.
- Future AI feedback can add dedicated speaking APIs without losing phase 0-3 metadata.

### Decision 4: Speaking is optional and must not block swipe navigation

Speaking entry points should augment existing vocabulary cards and daily learning, not replace the swipe session. Opening a speaking prompt, recording, retrying, or syncing metadata must not be required for normal card advancement.

Alternatives considered:

- Make speaking mandatory after a fixed number of cards. Rejected because learners may avoid the app if record prompts feel forced.
- Build a separate speaking-only app surface first. Rejected because vocabulary cards already provide the strongest context for the first speaking loop.

Rationale:

- Optional speaking reduces pressure for shy learners.
- Existing offline-first selection remains stable.
- Gentle prompts can encourage speaking after a learner has seen a word several times.

### Decision 5: Introduce mobile audio behind a service boundary and feature flag

Mobile should introduce an audio recorder/playback service abstraction and gate the first implementation behind a feature flag or configuration toggle. The implementation can choose the Flutter plugin during the mobile spike, but the app should isolate plugin-specific APIs from session and repository code.

Alternatives considered:

- Wire a plugin directly into the card widget. Rejected because permission, lifecycle, playback interruption, and testability concerns should be centralized.
- Delay audio plugin selection until after all backend work. Rejected because permission and device behavior are the highest mobile risk and should be spiked early.

Rationale:

- Audio plugin edge cases are easier to contain behind a service.
- Feature flagging supports alpha/beta rollout.
- Tests can mock record/playback without real microphone access.

### Decision 6: Weekly speaking summary is backend-owned, with local fallback display

The backend should expose a weekly speaking summary derived from accepted speaking events. Mobile can show local session summaries immediately, but cross-device or signed-in weekly summaries should come from backend data.

Alternatives considered:

- Only local summaries. Rejected because signed-in learners and beta analytics need backend-visible metrics.
- Build full analytics dashboards before beta. Rejected because phase 0-3 only needs basic adoption metrics.

Rationale:

- Backend summaries support product metrics without audio upload.
- Local summaries preserve immediate offline feedback.
- The same events can later feed broader speaking analytics.

## Risks / Trade-offs

- Audio plugin instability on Android/iOS -> Mitigate with an early mobile spike, a service abstraction, feature flagging, and permission/lifecycle tests.
- Learners may avoid recording because it feels embarrassing -> Mitigate with local-only privacy copy, optional entry points, positive summaries, and no harsh scoring.
- Prompt quality may be too low for useful speaking practice -> Mitigate with curated seed prompts, dashboard review, short A1/A2 length rules, and prompt-level `could_not_say` metrics.
- Extending study-event sync could regress existing rating/proficiency flows -> Mitigate with a discriminated event shape, separate speaking persistence, and focused tests that ensure speaking events do not update proficiency.
- Local audio storage can grow unexpectedly -> Mitigate with retention cleanup, delete controls, and storage tests.
- Dashboard scope can become too large -> Mitigate by limiting phase 0-3 dashboard work to prompt display, edit, status, and quality queue.

## Migration Plan

1. Add backend schema for `speaking_prompts` and `speaking_events` using idempotent migrations.
2. Deploy backend support for reading approved prompts and accepting speaking event payloads while preserving existing rating event behavior.
3. Add prompt fields to dashboard review screens behind existing admin access controls.
4. Add mobile data models and optional prompt rendering with fallback to existing example sentence when no prompt exists.
5. Add mobile audio record/playback behind a feature flag and keep audio local-only.
6. Enable internal alpha users, measure first recording conversion, and monitor sync errors before broader beta.

Rollback strategy:

- Disable the mobile feature flag to hide speaking UI.
- Backend can continue accepting rating events if speaking event support is unused.
- Speaking prompt/event tables can remain inert if the feature is rolled back.
- Dashboard prompt fields can be hidden without affecting article or vocabulary review.

## Open Questions

- Which Flutter audio recording/playback plugin is most reliable for the current Android/iOS targets?
- Should sample audio initially use device TTS, pre-recorded audio, or only text prompt plus learner recording?
- Should `speaking_prompts` be populated first from curated seed content or generated from article examples with dashboard approval?
- What exact weekly summary response shape should be added to the API contract?
- Should internal beta include explicit opt-in upload for a small set of audio samples to prepare the later AI feedback phase?
