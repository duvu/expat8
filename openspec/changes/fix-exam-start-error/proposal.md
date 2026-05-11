## Why

Every attempt to start an exam fails with "Failed to start exam, please try again" because the backend route guard still requires a `topic` field in the request body, but the mobile app was already updated to send only `language`. The validation block is dead code — the stores no longer accept or use `topic` at all — so every `POST /v1/exam/start` returns HTTP 400.

## What Changes

- Remove the stale `topic is required` validation from `backend/src/routes/exam.js` (lines 36–40).
- Remove the unused `topic` variable extraction from the same handler.
- Confirm no other route/handler references `topic` from the exam start body.
- Update backend exam tests to assert the route accepts a language-only body without error.

## Capabilities

### New Capabilities

_(none — this is a bug fix, no new capabilities are introduced)_

### Modified Capabilities

- `exam` _(no existing spec — implementation fix only, no spec-level requirement change)_

## Impact

- **Backend**: `backend/src/routes/exam.js` — one validation block removed.
- **Backend tests**: `backend/test/exam.test.js` — minor assertion cleanup if needed.
- **Mobile**: no changes required (already sends correct payload).
- **API contract**: `contracts/api.md` already documents language-only body; no change needed.
- **Database**: no schema changes.
