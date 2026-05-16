## Why

The expat8 codebase currently embeds production credentials, private infrastructure hostnames, and default secrets directly in source files, making the repository unsafe to publish publicly. Before open-sourcing, all sensitive values must be externalized to environment variables or removed, and placeholder documentation must replace real values in docs and scripts.

## What Changes

- Remove `expat8-mobile-secret` and `https://expat8.x51.vn` as hardcoded `defaultValue` fallbacks in `mobile/lib/src/config.dart` — replace with empty strings that fail loud at runtime if not supplied via `--dart-define`
- Remove `https://lite.x51.vn` as the hardcoded default for `LITELLM_BASE_URL` in `backend/src/config.js` — require explicit configuration
- Replace `expat8_password` inline fallback in `docker-compose.yml` with a `CHANGEME` placeholder that is clearly not a usable default
- Remove hardcoded production credentials from `backend/test/e2e_prod_test.mjs` — require `BACKEND_BASE_URL`, `APP_ID`, and `APP_SECRET` to be set via environment; skip/fail tests if missing
- Replace `expat8-mobile-secret`, `https://expat8.x51.vn`, and `docker.x51.vn` references in all docs, README, CLAUDE.md, and `.github/copilot-instructions.md` with `<YOUR_APP_SECRET>`, `<YOUR_BACKEND_URL>`, and `<YOUR_REGISTRY>` placeholders
- Scrub or redact the internal server IP (`10.113.213.9`) and private Docker registry path from `.serena/` memory files that could be included in the public repo
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
- **Backend**: `config.js` — `LITELLM_BASE_URL` default removed; `docker-compose.yml` — DB password placeholder changed
- **Tests**: `backend/test/e2e_prod_test.mjs` — must now be run with explicit env vars; CI must supply them or skip the file
- **Docs / README / CLAUDE.md / `.github/`**: All occurrences of `expat8-mobile-secret`, `https://expat8.x51.vn`, `docker.x51.vn` replaced with placeholders
- **`.serena/` memories**: Internal IP and private registry paths scrubbed
- **No API contract changes** — purely configuration and documentation hygiene
