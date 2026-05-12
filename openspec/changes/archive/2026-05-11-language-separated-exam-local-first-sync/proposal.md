## Why

The current exam flow needs to split cleanly by language so English exams never surface Chinese content and Chinese exams never surface English content. Exam attempts also need to be reliable when the backend is slow or unavailable, so results must be stored locally first and synchronized later without blocking the user.

## What Changes

- Make exam content selection language-isolated so each exam only uses vocabulary from the active language.
- Prevent cross-language leakage in exam questions, prompts, and result context.
- Persist exam results locally first on the mobile client, then sync them to the backend in the background.
- Keep the exam flow responsive when backend submission or sync is delayed or fails.
- Add test coverage for language isolation and offline-first result persistence/sync behavior.

## Capabilities

### New Capabilities
- `language-separated-exam`: exam question selection and presentation constrained to the active language only.
- `exam-result-sync`: local-first exam result storage with deferred backend synchronization and retry behavior.

### Modified Capabilities
- _(none)_

## Impact

- **Mobile**: exam question selection, result persistence, and sync queue handling.
- **Backend**: exam result ingestion and idempotent sync behavior may need updates to accept deferred submissions.
- **Data model**: local exam attempt storage and sync metadata.
- **Tests**: coverage for language separation, offline submission, and sync retry behavior.
