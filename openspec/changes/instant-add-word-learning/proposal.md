## Why

The current `Add word` flow is built around asynchronous submission, polling, and queued local sync, which makes a simple learner action feel slow and uncertain. We now want `Add word` to behave like immediate study input: if the word already exists, return it immediately; if it does not, generate it through the backend in the same request, save it canonically, and count the result as one learned exposure right away.

## What Changes

- Change `POST /v1/user-submitted-words` from an asynchronous submission endpoint into an immediate resolution flow.
- When the submitted normalized term already exists in canonical vocabulary, return the existing word immediately and treat the action as one learning exposure.
- When the submitted normalized term does not exist, call the backend AI generation path during the request, persist the generated canonical word, return it immediately, and treat the action as one learning exposure.
- Remove the learner-facing dependency on queued/processing polling for the normal `Add word` flow.
- Update mobile `Add word` so it imports the returned word into the normal local vocabulary inventory immediately and updates local learning history/progress as one learned action.
- Update API and mobile/backend tests to cover immediate existing-word resolution, immediate AI generation, and immediate learned-state effects.

## Capabilities

### New Capabilities
- `instant-word-resolution`: The `Add word` flow resolves a submitted term in a single request, either by returning an existing canonical word or generating and persisting a new one immediately.

### Modified Capabilities
- `mobile-word-capture`: The learner-facing `Add word` flow no longer relies on queued submission/polling for normal operation and instead imports a ready word immediately into the local study inventory.
- `user-submitted-vocabulary`: Backend submitted-vocabulary handling changes from async worker-based learner resolution to synchronous immediate resolution for the normal mobile capture path.
- `mobile-learning-progress-stats`: A successful `Add word` action counts as one learned item immediately in local progress totals.
- `mobile-learning-history-view`: A successful `Add word` action appends the resolved word to the local learned history trail as one learned event.

## Impact

- `backend/src/routes/user.js`
- `backend/src/word_store.js`
- `backend/src/postgres_word_store.js`
- `backend/src/generation_service.js`
- `backend/test/`
- `contracts/api.md`
- `mobile/lib/src/api/backend_api_client.dart`
- `mobile/lib/src/models/submitted_word.dart`
- `mobile/lib/src/data/local_database.dart`
- `mobile/lib/src/data/word_repository.dart`
- `mobile/lib/src/ui/submitted_words_screen.dart`
- `mobile/test/`
