# Expat8 Language Learning MVP

This workspace contains the OpenSpec-driven MVP implementation for a Flutter vocabulary learning app and a lightweight backend service.

## Adaptive Proficiency

The current app/backend flow includes adaptive language-native proficiency ladders:

- English initializes at `A1` and progresses on CEFR (`A1` to `C2`)
- Chinese initializes at `HSK1` and progresses on HSK (`HSK1` to `HSK6`)
- Mobile shows the current level in the top-right corner of the learning screen
- Rating buttons are `Easy`, `Too Easy`, `Hard`, and `Too Hard`
- Backend upgrades proficiency after 5 consecutive `too_easy` ratings
- Backend downgrades proficiency after 5 consecutive `hard` ratings
- `/v1/words/next` can filter by explicit `proficiency_level` or by resolved device proficiency
- Proficiency responses are scale-native (`scale`, `level`, `level_index`) with additive aliases during migration

Compatibility mode is controlled by `PROFICIENCY_COMPATIBILITY_MODE` (`additive` by default, `strict` to disable aliases).

See `contracts/api.md` for the request and response shapes.

## Structure

- `mobile/`: Flutter app source for Android and iOS.
- `backend/`: Node.js backend service using ExpressJS and `node:test`.
- `contracts/`: mobile-backend API contracts.
- `docs/`: product and technical documentation.
- `openspec/`: change proposal, design, specs, and tasks.

## Local Configuration

Mobile compile-time values:

```bash
flutter run \
	--dart-define=BACKEND_BASE_URL=https://expat8.x51.vn \
	--dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
	--dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
	--dart-define=APP_CREDENTIAL_SECRET=expat8-mobile-secret
```

Backend environment:

```bash
cd backend
copy .env.example .env
npm test
npm start
```

The backend requires signed app credential headers for `/v1/*` requests.
`GET /health` remains unsigned for health checks. See `contracts/api.md` and
`docs/app-credential-security.md` for the signing contract.

The backend test suite now covers adaptive proficiency state, CEFR filtering,
single-event submission, and sync responses:

```bash
cd backend
npm test
```

Docker Compose backend stack:

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
curl http://localhost:8787/health
docker compose logs -f backend
docker compose down
```

The Compose stack builds the ExpressJS backend image, starts PostgreSQL,
initializes the database from `backend/db/schema.sql`, and exposes the backend
on `http://localhost:${BACKEND_PORT:-8787}`. LiteLLM is optional for local smoke
tests. Without a reachable LiteLLM server or API key, the backend falls back to
stored words and rejects failed generation attempts without exposing sensitive
data.
