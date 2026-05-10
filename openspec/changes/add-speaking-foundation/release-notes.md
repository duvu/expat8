# Release Notes — Speaking Foundation (Phase 0-3)

**Change:** `add-speaking-foundation`
**Scope:** Backend, Mobile, Dashboard
**Phase:** 0-3 (local record/playback, drill, metadata sync — no AI scoring)

---

## What ships in this release

### Mobile

- **Speaking panel on vocabulary cards** — An optional microphone entry point appears on vocabulary cards when a reviewed speaking prompt is available. Learners can read the target sentence, record themselves, play back, retry, and self-rate without leaving the learning session.
- **3-minute speaking drill** — A short drill that selects up to five cached prompts from recently learned or due-review cards. Ends with a positive summary showing spoken sentence count, retry effort, and approximate speaking time.
- **Local-only audio storage** — Recordings stay on the device. No audio is uploaded to the backend or included in any API payload. Local paths are never logged.
- **Retention cleanup** — Audio older than the configured retention window is automatically removed on app start.
- **Delete controls** — Users can delete a single recording or all local speaking recordings from the settings screen.

### Backend

- **`speaking_prompts` table** — Curated prompts linked to `word_senses` (and optionally `article_terms`). Each prompt carries `target_text`, `vi_hint`, `target_phrase`, `pronunciation_tip_vi`, `common_mistake_vi`, `difficulty`, `topic`, `status`, and review metadata.
- **`speaking_events` table** — Accepts speaking metadata from signed study-event sync batches. Keyed by client event ID for idempotency. Never stores audio.
- **Discriminated study-event sync** — `POST /v1/study-events/sync` accepts a union of existing rating events and new speaking event types. Speaking events do not update proficiency or SRS state.
- **Speaking event types accepted:** `speaking_prompt_viewed`, `speaking_sample_played`, `speaking_recorded`, `speaking_retried`, `speaking_self_rated_clear`, `speaking_self_rated_close`, `speaking_self_rated_hard`, `speaking_drill_completed`.
- **Weekly speaking summary** — `GET /v1/speaking/summary` returns spoken sentence count, retry count, self-rating counts, total duration, and first recording timestamp for the current week.
- **Approved prompt in learning cards** — `POST /v1/learning/cards` includes `speaking_prompt` in each card when an approved prompt is linked to the word sense.

### Dashboard

- **Prompt review screen** — Vocabulary review UI now shows the associated speaking prompt when present. Reviewers can view, edit, approve, or reject prompts.
- **Prompt quality queue** — A dedicated queue surfaces prompts that are pending review or missing required fields.

---

## Privacy behavior

| What | Behavior |
|------|----------|
| Learner recordings | Stored locally on device only; never uploaded |
| Audio file paths | Stripped from all backend payloads and mobile logs |
| Speaking metadata | Duration, retry count, self-rating, prompt ID synced to backend; no identifying acoustic data |
| Retention | Configurable retention window; default cleanup on app start |
| Delete controls | Per-recording delete and bulk delete available in settings |

Users see the following in-app copy before first recording:
> "Your recordings are private and saved only on this device."

---

## Feature flag

Speaking UI is gated behind a compile-time flag. The flag is **off by default**.

| Target | Flag | How to enable |
|--------|------|---------------|
| Mobile (Flutter) | `SPEAKING_FOUNDATION_ENABLED` | Build with `--dart-define=SPEAKING_FOUNDATION_ENABLED=true` |

When the flag is `false`:
- No microphone permission is requested.
- Speaking entry points do not render on vocabulary cards.
- Drill entry point is not shown.
- Speaking events are still accepted by the backend if sent by a future build.

---

## Known limitations in phase 0-3

- **English only** — Speaking prompts and drill are limited to English target language in this release.
- **No AI pronunciation scoring** — Self-rating is the only feedback mechanism. AI scoring will be introduced in a later phase with explicit user opt-in.
- **No speech-to-text** — Recording is played back as-is; no transcription or word-level comparison.
- **No audio upload opt-in** — Even voluntary upload for AI analysis is not yet available. Users who want AI feedback must wait for a future phase.
- **No human coach review** — Recordings are not reviewable by coaches or shared with the community.
- **Prompt availability depends on content pipeline** — Speaking prompts appear on cards only after an approved prompt is linked to the word sense. Early users may see few or no prompts until the content library grows.
- **Nonce replay protection requires live Postgres** — `PostgresNonceCache` requires the `nonces` migration; falls back to in-memory per-process cache if `DATABASE_URL` is absent.

---

## Beta rollout order

1. **Internal alpha** (team devices only, flag enabled in internal builds)
   - Verify microphone permission flow on Android and iOS
   - Confirm audio stays local and does not appear in backend logs
   - Measure first recording conversion (`speaking_recorded` event count / `speaking_prompt_viewed` count)
   - Confirm speaking events do not change proficiency or due-review counts

2. **Closed beta** (invited learners, flag enabled in beta builds)
   - Monitor `speaking_drill_completed` event rate vs card swipe rate
   - Inspect backend `speaking_events` table for schema consistency
   - Watch for sync errors (`rejected` event keys) in batch responses
   - Gather subjective prompt quality feedback from reviewers

3. **Broad enablement**
   - Build production release with `--dart-define=SPEAKING_FOUNDATION_ENABLED=true`
   - Ensure speaking prompt library has ≥ 50 reviewed and approved prompts
   - Confirm weekly speaking summary endpoint returns correct counts
   - Complete the content-ingestion rollout checklist (`rollout-checklist.md`) so new article vocabulary populates speaking prompts automatically

---

## Rollback

- **Mobile:** Rebuild and ship without `--dart-define=SPEAKING_FOUNDATION_ENABLED=true`. No data migration required; local audio stays inert on device.
- **Backend:** Stop worker to pause prompt population. `speaking_prompts` and `speaking_events` tables remain inert. Existing rating/proficiency flows are unaffected.
- **Dashboard:** Prompt review UI can be hidden without affecting vocabulary review flow.
