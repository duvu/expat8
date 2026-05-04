# Expat8 Language Learning MVP

This workspace contains the OpenSpec-driven MVP implementation for a Flutter vocabulary learning app and a lightweight backend service.

## Structure

- `mobile/`: Flutter app source for Android and iOS.
- `backend/`: Node.js backend service using built-in HTTP and test modules.
- `contracts/`: mobile-backend API contracts.
- `docs/`: product and technical documentation.
- `openspec/`: change proposal, design, specs, and tasks.

## Local Configuration

Mobile compile-time values:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8787 --dart-define=NEW_WORD_TIMEOUT_SECONDS=5
```

Backend environment:

```bash
cd backend
copy .env.example .env
npm test
npm start
```

LiteLLM is optional for local smoke tests. Without a reachable LiteLLM server, the backend falls back to stored seed words and rejects failed generation attempts without exposing sensitive data.
