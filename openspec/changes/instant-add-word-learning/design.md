## Context

The current `Add word` flow was introduced through `capture-user-submitted-vocabulary` and is modeled as an asynchronous submission pipeline. Mobile creates a local `SubmittedWord` entry, enqueues a `submitted_word_create` sync task, posts to `POST /v1/user-submitted-words`, then polls `GET /v1/user-submitted-words` until the backend worker resolves the submission. This architecture is robust for background processing, but it is too indirect for the learner-facing `Add word` action.

Today the backend already short-circuits one branch synchronously: if the submitted normalized term already exists in canonical `words`, `createUserSubmittedWord()` immediately returns a ready/existing-word response. The missing branch is the non-existing-word path, which still creates a queued submission and worker job. Mobile also imports ready words into local vocabulary, but it does not currently treat `Add word` success as a learned action in local learning history/progress.

This change cuts across backend request handling, canonical word persistence, mobile repository state handling, and the learner-facing history/progress features. A design document is useful because the main decision is behavioral, not cosmetic: we are reclassifying `Add word` from async submission management into an immediate learning action.

## Goals / Non-Goals

**Goals:**
- Make normal `Add word` resolution synchronous from the learner's perspective.
- Reuse the existing canonical vocabulary generation/persistence contract instead of creating a parallel data model.
- Preserve deduplication semantics for repeated submissions and existing canonical words.
- Import the resolved word into local vocabulary immediately on mobile.
- Count a successful `Add word` result as one learned exposure in local history and progress totals.
- Keep the change minimal by reusing current route names, models, and as much storage structure as possible.

**Non-Goals:**
- Rebuild the entire submitted-word persistence model or remove its historical records from the database.
- Introduce a brand-new endpoint just for instant add-word resolution if the existing endpoint can be adapted cleanly.
- Change the gesture-based learning semantics or broader SRS model beyond the one immediate learned exposure required here.
- Guarantee offline add-word creation. If the backend request cannot complete, the learner sees failure rather than queued later processing.
- Rework dashboard/admin flows for submitted-word jobs unless required to keep the backend coherent.

## Decisions

### 1. Keep `POST /v1/user-submitted-words`, but make it terminal in-request

The existing route already owns authentication, device context, deduplication intent, and response shaping. The smallest correct change is to keep this route and change the store behavior behind it.

Decision:
- Existing canonical word match stays immediate, as it already is.
- Missing canonical word path will call the existing `generationService.generateSubmittedWord()` during the request instead of creating a queued worker job.
- The backend still persists a learner-owned submission row for dedupe/history, but it should be terminal (`ready` or `failed`) by the time the HTTP response returns.

Rationale:
- Preserves API continuity and mobile wiring.
- Reuses `generation_source=user_submission` and existing validation logic.
- Avoids inventing a second submission endpoint or duplicating auth rules.

Alternative considered:
- Add a new `POST /v1/user-submitted-words/resolve-now` endpoint and keep the old route intact. Rejected because it duplicates contracts and increases client complexity for little benefit.

### 2. Treat worker-based queued processing as out of the normal learner path

The current worker pipeline (`user_submitted_word_jobs`, `submitted_word_worker.js`) exists because generation was intentionally deferred. For this change, the main learner path should no longer create queued or processing states.

Decision:
- `createUserSubmittedWord()` in both stores will stop creating queued jobs for the normal request path.
- A failed in-request generation will produce a terminal failed submission record or an immediate request error, but not a learner-visible queued record.

Rationale:
- The user's requested behavior is “trả lại ngay” and “load từ AI luôn”.
- The learner should not have to manage submission lifecycle for a simple add-word action.

Alternative considered:
- Keep writing queued jobs as a fallback after synchronous generation timeout. Rejected because it violates the immediate/definitive learner expectation and complicates UI semantics again.

### 3. On mobile, replace queued submission management with immediate import-and-mark flow

The repository currently creates a local `queuedSync` record, enqueues sync work, then later merges the resolved word from polling. That no longer matches the desired behavior.

Decision:
- `submitSubmittedWord()` becomes a direct online request path.
- On success, mobile upserts the returned `resolvedWord`, stores a terminal local submission/history record if still useful for the screen, and immediately marks the word as learned in local state.
- On failure, mobile shows immediate failure feedback rather than queuing a pending submission lifecycle.

Rationale:
- The returned word is already canonical and ready to use in the same code path as normal vocabulary.
- Removing queue/poll behavior from the normal path makes the screen simpler and matches user intent.

Alternative considered:
- Keep the queue model internally but auto-refresh immediately after create. Rejected because it still depends on intermediate states and background sync artifacts that the user no longer wants.

### 4. Count “Add word success” as a local learned event by reusing existing learning-state primitives

The current learned gesture updates local history/progress through `markWordLearned()`. That function already appends learning history and increments the learned tally indirectly via local state.

Decision:
- After importing the resolved word locally, mobile will transition it into the same local “learned once” state by reusing `markWordLearned()` and `markWordAsLearning()` semantics as needed.
- The implementation should avoid degrading an already-progressed local word. If the resolved word already exists locally with stronger progress, the repository should preserve that state instead of overwriting it blindly.

Rationale:
- Reuses existing progress and history infrastructure.
- Keeps “count as one learning” consistent with current vocabulary history UI.

Alternative considered:
- Emit a synthetic study event to backend immediately for the add-word action. Rejected as the primary mechanism because the request already does useful work and the user explicitly asked for “coi như một lần học” in product behavior; local history/progress should update instantly regardless of sync. Backend study-event emission may still be added if needed after local behavior is settled.

### 5. Preserve existing local word progress when the canonical word already exists locally

`LocalDatabase.upsertWord()` preserves `learningState` but overwrites `status`, `lastSeenAt`, and `nextReviewAt` from the incoming payload. A naive import of an already-known word could accidentally reset a review/mastered card back to `newWord`.

Decision:
- The repository/local database path for resolved submitted words should merge carefully: preserve stronger existing study status/schedule when a local copy already exists, while still recording the add-word action as one learned event if the product wants it counted.

Rationale:
- Prevents regression of existing learner progress.
- Avoids a surprising downgrade when the learner adds a word that was already in their local inventory.

Alternative considered:
- Always trust the backend payload and overwrite local status. Rejected because backend payloads for words are card-oriented and do not reflect the learner's full local progression state.

## Risks / Trade-offs

- [Risk] In-request AI generation increases perceived request latency for new words -> Mitigation: keep using the existing backend client timeout, log request duration, and surface clear failure feedback when generation does not complete.
- [Risk] Existing mobile tests and UI assume queued/processing states -> Mitigation: update tests and the `Add word` screen copy/status rendering to focus on immediate terminal outcomes.
- [Risk] Preserving local progress while also counting add-word as one learned action can be ambiguous for already-known words -> Mitigation: define merge rules explicitly in implementation/tests so learned history increments without downgrading local status.
- [Risk] Background worker/job code may become partially unused -> Mitigation: scope this change to the normal mobile path first; clean up dead worker code only if it is clearly unused after implementation.
- [Risk] Contracts/docs may drift because older async language still exists in README/docs -> Mitigation: update canonical API contract and any current-facing docs touched by the add-word flow.

## Migration Plan

1. Update backend route/store behavior so `POST /v1/user-submitted-words` returns terminal results only for the normal learner flow.
2. Update mobile repository and screen to stop relying on queued submission sync/polling for normal add-word interactions.
3. Update local merge logic so resolved words are imported safely and marked as one learned exposure.
4. Update API/mobile/backend tests for both existing-word and generated-word immediate flows.
5. Update current docs/contracts.

Rollback:
- Revert store behavior to queued job creation and restore mobile queue/poll behavior. Because the endpoint path stays the same, rollback is code-level rather than contract-level routing change.

## Open Questions

- Should a successful `Add word` also emit a backend study event immediately, or is local learned-state/history/progress sufficient for this change?
- Should the UI keep a historical submission list at all once the main flow becomes immediate, or is a simple recent-results list enough?
- If synchronous generation becomes too slow in production, do we want a future admin/internal fallback path that reuses worker jobs without exposing queued states to the learner?
