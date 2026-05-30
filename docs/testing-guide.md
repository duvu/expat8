# Testing Guide

This guide collects the test and verification commands used across the Expat8 workspace.

## Backend

Run all backend tests:

```bash
cd backend
npm test
```

Run a single backend test file:

```bash
cd backend
node --test test/api.test.js
```

Run migration verification:

```bash
cd backend
npm run verify:migrations
```

Optional PostgreSQL integration coverage runs only when `TEST_DATABASE_URL` is set:

```bash
cd backend
TEST_DATABASE_URL=postgres://... npm test
```

`backend/test/e2e_prod_test.mjs` is a manual production smoke test and is not part of `npm test`.

## Mobile

Run all Flutter tests:

```bash
cd mobile
flutter test
```

Run a single Flutter test file:

```bash
cd mobile
flutter test test/learning_session_controller_test.dart
```

Regenerate ObjectBox bindings after entity changes:

```bash
cd mobile
flutter pub run build_runner build --delete-conflicting-outputs
```

Linux tests that touch ObjectBox require `mobile/lib/libobjectbox.so`.

## Dashboard

```bash
cd expat8-dashboard
npm test
npm run build
npm run lint
```

If lint tooling is incompatible with the installed Next.js version, report the exact output rather than assuming lint passed.

## Local Stack Smoke Test

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
curl http://localhost:8787/health
curl http://localhost:8787/health/ready
docker compose ps
docker compose logs -f backend
```

For API behavior, test against a running backend with signed `x-expat8-*` headers. Unsigned non-OPTIONS `/v1/*` requests should return `400 { "error": "bad_request" }`.

## Manual Production Checks

After Z440 backend deploy:

```bash
cd ~/deployment/worker-z440
docker compose ps expat8-backend
curl -i -sS http://<INTERNAL_HOST>:18787/health
```

For mobile release verification, install the rebuilt APK/AAB that was compiled with the intended `BACKEND_BASE_URL` and app credential values. Do not reuse a previous build after changing `--dart-define` inputs.

## Documentation Verification

For documentation-only changes, verify at minimum:

```bash
git status --short
git diff -- README.md docs/
```

Review links and commands for consistency with [`contracts/api.md`](../contracts/api.md), [`AGENTS.md`](../AGENTS.md), and module package files.
