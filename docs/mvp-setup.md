# MVP Setup and Limitations

## Prerequisites

- Flutter SDK 3.3 or newer for the mobile app.
- Node.js 22 or newer for the backend.
- Optional LiteLLM server for live AI vocabulary generation.

The current development machine used for this implementation has Node.js available but does not have Flutter or Dart on `PATH`, so only backend tests can be executed here.

## Backend

```bash
cd backend
copy .env.example .env
npm test
npm start
```

Environment values:

- `PORT`: backend HTTP port, default `8787`.
- `LITELLM_BASE_URL`: LiteLLM-compatible base URL.
- `LITELLM_API_KEY`: optional API key for LiteLLM.
- `LITELLM_MODEL`: model routed through LiteLLM.
- `DEFAULT_SOURCE_LANGUAGE`: default source language, currently `vi`.
- `DEFAULT_TARGET_LANGUAGE`: default target language, currently `en`.
- `NEW_WORD_TIMEOUT_SECONDS`: product timeout mirrored by mobile config.

## Mobile

```bash
cd mobile
flutter pub get
flutter test
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8787 --dart-define=NEW_WORD_TIMEOUT_SECONDS=5
```

The app uses a local SQLite database via `sqflite` and stores vocabulary, study events, and sync queue entries locally before sync.

## Smoke Test Coverage

Backend tests include a service-level smoke test that simulates:

- Fetching a new word from `/v1/words/next`.
- Saving it into a client-side local cache.
- Rating the word and adding a study event to a sync queue.
- Posting the event to `/v1/study-events/sync`.
- Verifying the backend stores the event idempotently.

## Known MVP Limitations

- No authentication is implemented. Server records use `device_id` and keep `user_id` nullable for future auth.
- The backend uses an in-memory store for runnable local tests plus `db/schema.sql` as the persistent database contract.
- The Flutter project is source-scaffolded but Android/iOS platform folders were not generated because Flutter SDK is unavailable in this environment.
- No pronunciation audio or speech scoring is included.
- AI generation failures are logged without user payloads and the backend can still serve stored seed words.
