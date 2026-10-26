# AGENTS.md

## Repo Shape
- `mobile/` — Flutter app (Dart, ObjectBox, SDK `>=3.3.0 <4.0.0`)
- `backend/` — Node.js 22 + Express 5, ESM (`"type": "module"`), `node:test` only (no Jest/Mocha)
- `expat8-dashboard/` — Next.js 15 admin web app (TypeScript, React 19); already wired in `docker-compose.yml`
- `contracts/api.md` — canonical API reference; wins over code when they conflict
- `backend/db/schema.sql` — authoritative DB schema; auto-applied by Compose on first start
- `backend/db/migrations/` — numbered SQL migrations; NOT auto-applied; verified via `npm run verify:migrations`

## Commands

### Backend
```bash
cd backend && npm test                        # all tests (node --test, no DB required for most)
cd backend && node --test test/api.test.js    # single file
cd backend && npm run start:worker            # article processing worker (separate process)
cd backend && npm run verify:migrations       # check migration content integrity
```
- PostgreSQL integration tests (`postgres_integration.test.js`) only run when `TEST_DATABASE_URL` is set; skip silently otherwise.
- `backend/test/e2e_prod_test.mjs` is a **manual production smoke test**; it is NOT part of `npm test`.

### Mobile
```bash
cd mobile && flutter test
cd mobile && flutter test test/learning_session_controller_test.dart  # single file
cd mobile && flutter pub run build_runner build --delete-conflicting-outputs  # after ObjectBox entity changes
```
- Linux desktop tests require `mobile/lib/libobjectbox.so` to be present.

### Dashboard
```bash
cd expat8-dashboard && npm run dev    # dev server (port 3000)
cd expat8-dashboard && npm run build
cd expat8-dashboard && npm run lint
```

### Local Stack
```bash
LITELLM_API_KEY=... docker compose up --build -d
```

## Non-Obvious Constraints

### API Auth
- All `/v1/*` requests require HMAC app-credential headers (`x-expat8-*`); missing → 400.
- Unsigned exceptions: `GET /health`, `GET /health/ready`, `OPTIONS /v1/*` (CORS preflight), and `GET /v1/exam/certificate/:id` (fully public, no headers at all).
- Signed-in requests keep the same `device_id` and add `Authorization: Bearer <session_token>`.
- `ADMIN_API_TOKENS` env var grants access to `/v1/admin/*` endpoints (checked after app credential verification → 403 if absent).

### Card Loading
- `POST /v1/learning/cards` must NOT include `exclude_server_word_ids`, `current_word_id`, or any exclusion fields → 400.
- `card_mode` must be `"new"` or absent; any other value → 400.
- Duplicate avoidance is backend-owned via learner state and `PUT /v1/user-word-cache` (cap: 1000 IDs).

### Admin Articles
- `PATCH /v1/admin/articles/:id` `visibility` accepts only `"private"` or `"published"`; `"shared"` → 400.

### Exam
- `POST /v1/exam/start` requires ≥ 5 studied words (`422 INSUFFICIENT_WORDS`), capped at 20 questions.
- Exam sessions expire after 2 hours (`410 SESSION_EXPIRED`).
- Passing score ≥ 70%; triggers certificate issuance.

### Mobile Build
- `BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, and other `--dart-define` values are compiled into the binary — **any change requires a full rebuild**.
- Android emulator cannot reach LAN/VPN IPs (`10.x.x.x`); use a public URL for emulator builds; LAN IPs only work on physical devices.

## Backend Architecture
- `backend/src/server.js` — thin entrypoint; delegates to `createBackendRuntime()` in `src/runtime.js`
- `backend/src/runtime.js` — wires store (`PostgresWordStore` when `DATABASE_URL` set; in-memory `WordStore` otherwise), scheduler, and server
- `backend/src/app.js` — Express app factory
- `backend/src/worker.js` — background article processing; run as a separate process
- Request pipeline (all `/v1/*`): CORS → requestContext → rejectMissingCredentialHeaders → captureRawBody → appCredentialGuard → parseJsonFromCapturedBody → route handlers

## Key Environment Variables
| Variable | Notes |
|---|---|
| `DATABASE_URL` | PostgreSQL; if unset, backend uses in-memory store |
| `TEST_DATABASE_URL` | Enables `postgres_integration.test.js` |
| `APP_CREDENTIALS_JSON` | JSON array `[{appId, secret, status}]` for HMAC signing |
| `ADMIN_API_TOKENS` | Comma-separated tokens for `/v1/admin/*` |
| `LITELLM_BASE_URL` / `LITELLM_API_KEY` / `LITELLM_MODEL` | LLM enrichment (optional) |
| `CORS_ALLOWED_ORIGIN` | Defaults to `*`; set exact origin in production |

## Deploy
- Production target: `~/deployment/worker-z440/docker-compose.yml` (NOT the repo's local compose).
- Production backend port: `18787` (local dev: `8787`).
- Tag convention: `YYYYMMDD.HHMM`.
- Full deploy sequence in `.github/copilot-instructions.md`.

## Reference Files
- `CLAUDE.md` and `.github/copilot-instructions.md` — deploy/build details.
- `.wolf/*` — active OpenWolf memory; update when you learn something durable.
- `contracts/api.md` — trust this over handler code for API behavior.

## Programming Rules

Agent MUST follow these principles for every implementation and code review:

### SOLID
- Keep each class, module, function, and component focused on one responsibility.
- Depend on abstractions or narrow interfaces where this reduces coupling; avoid hard-coding infrastructure details into domain logic.
- Prefer composition and small, replaceable units over deep inheritance hierarchies.
- New code must be open for extension without requiring risky changes to stable behavior, and substitutable implementations must honor the same contract.
- Do not introduce an abstraction solely to satisfy the acronym; it must provide a clear testing, replacement, or separation benefit.

### DRY
- Keep business rules, validation, API contracts, design tokens, and shared transformations defined in one authoritative place.
- Before adding duplicated logic, search for an existing helper, service, hook, component, or token that can be reused.
- Do not prematurely generalize code that only happens to look similar; extract shared code when the behavior and change reason are genuinely the same.

### KISS
- Choose the simplest design that correctly satisfies the requirement and existing contracts.
- Prefer readable control flow, explicit data transformations, and standard project conventions over clever abstractions or unnecessary indirection.
- Keep functions, components, and files small enough to understand locally; split them when responsibilities or change reasons diverge.
- Avoid adding dependencies, patterns, configuration, or runtime complexity without a concrete benefit.

### YAGNI
- Implement only requirements that are currently requested or required by an existing contract.
- Do not add speculative extension points, unused configuration, premature optimization, or hypothetical error handling.
- Preserve existing behavior unless the task explicitly requires a behavior change; document intentional contract changes and update tests.

### General implementation requirements
- Read the relevant existing code, tests, and canonical documentation before modifying behavior.
- Keep API behavior aligned with `contracts/api.md`; when code and contract disagree, treat the contract as authoritative and call out the discrepancy.
- Validate inputs at boundaries, return actionable errors, and avoid leaking secrets or sensitive data in logs and responses.
- Add or update focused tests for changed behavior. Do not weaken or delete tests merely to make the suite pass.
- Keep changes scoped to the request. Avoid unrelated refactors and formatting churn.
- Before handoff, run the narrowest relevant checks, then broader checks when practical, and report any checks that could not be run.

## Frontend Theme Rules

These rules apply to `expat8-dashboard/` and any future frontend surfaces in this repository. The visual theme MUST be consistent across the entire project.

- Define colors, typography, spacing, border radii, shadows, breakpoints, and component states as shared design tokens in the existing theme/design-system location. Do not scatter raw visual values throughout pages or components.
- Reuse the shared theme and existing UI primitives before creating a new component or one-off style. New primitives must be justified and documented by their reusable purpose.
- Keep light/dark mode behavior, semantic colors, focus states, hover states, disabled states, loading states, and error states consistent across screens.
- Use the same visual language for buttons, forms, tables, cards, dialogs, navigation, alerts, empty states, and responsive layouts. Variants must come from the theme rather than ad-hoc overrides.
- Do not introduce page-specific colors, fonts, spacing scales, radii, shadows, or arbitrary breakpoints unless the exception is necessary, documented, and added to the shared design system.
- Ensure accessible contrast, visible keyboard focus, readable text sizing, semantic HTML, and usable touch targets while preserving the established theme.
- When changing the theme, review all affected screens and update snapshots, visual tests, or screenshots where the project provides them.
- A frontend change is incomplete if it works functionally but makes the product visually inconsistent with the rest of the project.
