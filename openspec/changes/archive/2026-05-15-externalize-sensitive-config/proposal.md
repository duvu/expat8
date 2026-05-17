## Why

The expat8 codebase currently embeds production credentials, private infrastructure hostnames, and default secrets directly in source files, making the repository unsafe to publish publicly. Before open-sourcing, all sensitive values must be externalized to environment variables or removed, and placeholder documentation must replace real values in docs and scripts.

## What Changes

- Remove hardcoded mobile credential and backend URL defaults in `mobile/lib/src/config.dart` — replace with empty strings that fail loud at runtime if not supplied via `--dart-define`
- Remove the hardcoded LiteLLM default in `backend/src/config.js` — require explicit configuration
- Replace the compose DB password fallback in `docker-compose.yml` with a clearly non-secret placeholder
- Remove hardcoded production credentials from `backend/test/e2e_prod_test.mjs` — require `BACKEND_BASE_URL`, `APP_ID`, and `APP_SECRET` to be set via environment; skip/fail tests if missing
- Replace real secret, URL, and registry references in docs, README, CLAUDE.md, and `.github/copilot-instructions.md` with placeholders
- Scrub or redact internal server IPs and private Docker registry paths from `.serena/` memory files that could be included in the public repo
- Add a `.env.example` note and `CONTRIBUTING.md` section explaining that all credentials must come from environment — confirm `backend/.env.example` uses only placeholder values
- Add `backend/.env` to `.gitignore` if not already there; ensure no `.env` file with real values is tracked

## Capabilities

### New Capabilities

- `open-source-readiness`: Defines the requirement that no secret, private URL, or internal hostname may appear as a hardcoded default in source code, default configuration, or checked-in documentation.

### Modified Capabilities

- `mobile-app-credential-signing`: Requirement changes — `APP_CREDENTIAL_APP_ID` and `APP_CREDENTIAL_SECRET` MUST NOT have non-empty default values in `config.dart`; builds without explicit `--dart-define` MUST fail credential validation at startup.
- `backend-litellm-runtime-config`: Requirement changes — `LITELLM_BASE_URL` MUST NOT have a hardcoded production default in `config.js`; the server MUST refuse to start LLM features if the variable is unset.

## Impact

- **Mobile**: `config.dart` — credential and URL defaults removed; any build pipeline not supplying `--dart-define` values will produce a non-functional app (intentional)
- **Backend**: `config.js` — hardcoded LLM default removed; `docker-compose.yml` — DB password placeholder changed
- **Tests**: `backend/test/e2e_prod_test.mjs` — must now be run with explicit env vars; CI must supply them or skip the file
- **Docs / README / CLAUDE.md / `.github/`**: All occurrences of secret, URL, and registry references replaced with placeholders
- **`.serena/` memories**: Internal IP and private registry paths scrubbed
- **No API contract changes** — purely configuration and documentation hygiene
