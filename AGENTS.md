# AGENTS.md

## Repo Shape
- `mobile/` is the Flutter app.
- `backend/` is the Node.js 22 + Express API.
- `contracts/api.md` is the API contract to trust when code and prose differ.
- `docker-compose.yml` starts PostgreSQL + backend for local stack work.

## High-Signal Commands
- Backend: `cd backend && npm test`
- Backend worker: `cd backend && npm run start:worker`
- Backend migration check: `cd backend && npm run verify:migrations`
- Mobile: `cd mobile && flutter test`
- Mobile codegen after ObjectBox entity changes: `cd mobile && flutter pub run build_runner build --delete-conflicting-outputs`
- Local stack: `LITELLM_API_KEY=... docker compose up --build -d`

## Non-Obvious Constraints
- All `/v1/*` requests require app-credential headers; `GET /health` is the only unsigned route.
- Mobile card loading is `POST /v1/learning/cards` with `card_mode: "new"`; do not add client exclusion lists for refill.
- Duplicate avoidance is backend-owned through learner state and `PUT /v1/user-word-cache`.
- Signed-in requests still send the same `device_id` and add `Authorization: Bearer <session_token>`.
- `BACKEND_BASE_URL` and other `--dart-define` values are compiled into the mobile binary.

## Backend Notes
- `backend/src/server.js` starts the API; `backend/src/worker.js` starts article processing.
- The backend falls back to in-memory `WordStore` when `DATABASE_URL` is unset; `PostgresWordStore` is the production path.
- Keep the API contract in `contracts/api.md` aligned with actual handler behavior.

## Verification Order
- Prefer focused tests over full suites when touching one package.
- If backend contract behavior changes, run the relevant `node --test` file(s) plus `npm test`.
- If mobile request flow or local storage changes, run the relevant `flutter test` file(s) plus `flutter test`.

## Existing Guidance Worth Preserving
- `CLAUDE.md` and `.github/copilot-instructions.md` contain repo-specific deploy/build details.
- `.wolf/*` files are active OpenWolf memory; update them when you learn something durable.
