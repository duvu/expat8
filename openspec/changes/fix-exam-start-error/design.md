## Context

The `POST /v1/exam/start` route handler in `backend/src/routes/exam.js` contains a validation block that requires a `topic` field in the request body. This guard was not removed when the stores (`word_store.js` and `postgres_word_store.js`) were updated to drop the `topic` parameter entirely as part of the `exam-auto-advance-flow` change. The stores now hardcode `topic: 'language'` and select words by language only.

The mobile client was correctly updated to send only `{"language": "en"}` — no `topic`. The result is that every `POST /v1/exam/start` call returns HTTP 400 (`bad_request: topic is required`) before reaching the store.

Additionally, the route still passes `topic` as a parameter to `store.startExamSession()`, even though the stores ignore it. The `INSUFFICIENT_WORDS` error message also references `"topic"` which is misleading.

## Goals / Non-Goals

**Goals:**
- Remove the `topic is required` validation block from the exam start route.
- Remove the now-unused `topic` variable extraction from the route.
- Stop passing `topic` to `store.startExamSession()` (stores ignore it already).
- Update the `INSUFFICIENT_WORDS` error message to reference `language` not `topic`.
- Confirm backend tests pass with language-only exam start.

**Non-Goals:**
- Changes to mobile code (already correct).
- Changes to the store implementations (already correct).
- Removing the legacy `GET /v1/exam/topics` endpoint.
- Database schema changes.

## Decisions

### Remove validation at the route layer only

The fix is entirely in `backend/src/routes/exam.js`. Both stores already accept no `topic` parameter and work correctly. The mobile is already correct. Only the route's dead validation guard needs removal.

**Alternative considered**: Add `topic` back to the mobile request. Rejected — the stores no longer use it, doing so would be introducing backwards-looking complexity with no benefit.

### Update INSUFFICIENT_WORDS message

The message currently says `Not enough studied words for topic "${topic}" in language "${language}"`. Since `topic` is now always `null` (never passed), the message would render as `for topic "null"`. Update to `Not enough studied words for language "${language}"`.

## Risks / Trade-offs

- **Risk**: Any other client sending `topic` will have it silently ignored. → Acceptable — stores already ignore it; no behaviour change.
- **Risk**: Test assertions check for the old `topic` error message. → Low — addressed by updating the test.
- **No rollback complexity**: change is a single-file, additive deletion; reverting is a one-line restore.
