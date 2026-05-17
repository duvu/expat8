## Context

The expat8 codebase is being prepared for public release. An audit found that production credentials, private infrastructure hostnames, and default secrets are hardcoded across source files, docs, and configuration. The specific findings are:

- `mobile/lib/src/config.dart`: production backend URL and app secret as `String.fromEnvironment` default values — compiled into the binary if `--dart-define` is omitted
- `backend/src/config.js`: private AI proxy URL as hardcoded default for `LITELLM_BASE_URL`
- `docker-compose.yml`: inline fallback DB password in multiple service definitions
- `backend/test/e2e_prod_test.mjs`: production URL and production app credentials as JS-level string defaults
- Docs, README, CLAUDE.md, `.github/copilot-instructions.md`, openspec archive tasks: secret, URL, and registry placeholders in example commands
- `.serena/` memory files: internal server IP and private Docker registry image paths

No API contracts change. This is a purely defensive, hygiene-focused change.

## Goals / Non-Goals

**Goals:**
- Ensure no real credential, private URL, or internal hostname appears in any file that will be committed to a public repo
- Replace hardcoded defaults in code with empty strings (or no default) so missing configuration is caught at startup, not silently ignored
- Replace real values in docs/scripts with clearly marked placeholders (`<YOUR_APP_SECRET>`, `<YOUR_BACKEND_URL>`, `<YOUR_REGISTRY>`)
- Ensure `.env` files with real values are in `.gitignore` and not tracked
- Scrub `.serena/` memory files of internal IPs and private registry paths

**Non-Goals:**
- Credential rotation (done separately by the operator after this change lands)
- Changing the credential signing architecture or authentication scheme
- Adding secret scanning CI (valuable follow-on, separate change)
- Refactoring `config.dart` or `config.js` beyond removing the offending default values

## Decisions

**Decision: Empty-string default instead of panic-on-missing for `config.dart`**

`String.fromEnvironment` cannot throw at compile time. The options were:
1. Use empty string as default — `AppConfig.backendBaseUrl` will be `''`, causing an immediate `SocketException` on first request; the failure is loud and obvious.
2. Use a sentinel value and assert in the constructor — catches the error earlier (app startup), but adds code complexity.

Chose option 1 (empty string) for simplicity. The existing `AppConfig` validates nothing today; adding an assert for the URL being non-empty during initialization is a clean follow-up but out of scope here.

**Decision: Remove LiteLLM default URL entirely, not replace with a non-functional placeholder**

If `LITELLM_BASE_URL` is absent the backend currently falls back to the real production proxy. The fix removes the fallback so `config.js` exposes `undefined` / `null` when the env var is missing. The LLM generation pathway already handles failures gracefully (words fall back to stored data), so this will not crash the backend — it will simply fail LLM calls and log appropriately.

Replacing with a localhost placeholder (`http://localhost:4000`) was considered but rejected: it would silently succeed in docker-compose environments where a LiteLLM container is running, giving a false sense that no configuration is needed.

**Decision: Replace `docker-compose.yml` password default with `CHANGEME`, not remove it**

Docker Compose requires a value for `POSTGRES_PASSWORD`. Removing the fallback entirely would break `docker compose up` without an `.env` file, which harms local development ergonomics. Using `CHANGEME` as the default makes the intent obvious and is not a real credential. The `.env.example` documents the correct way to set a real password.

**Decision: Scrub `.serena/` memory files, do NOT delete the directory**

The `.serena/` directory contains AI-agent memories that are useful for future development sessions. Rather than excluding the whole directory from the repo, the specific memory files that contain the internal IP and private registry paths will have those values replaced with redacted placeholders. This preserves the operational context while removing sensitive data.

**Decision: Replace in docs/README/CLAUDE.md inline, do NOT create a separate secrets-substitution script**

The number of affected files is bounded and the changes are simple string substitutions. A script would add complexity with no meaningful benefit over direct edits.

## Risks / Trade-offs

- **[Risk] Existing CI pipelines that rely on `config.dart` defaults will produce non-functional builds** → Mitigation: CI must already be supplying `--dart-define` values for release builds (the `.aab` was built with them). Debug/test builds without dart-defines will stop silently working against production, which is the desired behavior.
- **[Risk] Local `docker compose up` without a `.env` will hit `CHANGEME` as the DB password** → Mitigation: `backend/.env.example` documents all required variables. A clear `README.md` note directs developers to copy `.env.example` to `.env` and fill in values before starting the stack.
- **[Risk] `backend/test/e2e_prod_test.mjs` will silently skip or fail in CI if env vars are not set** → Mitigation: The test file will be updated to explicitly check for required env vars and `process.exit(1)` or skip gracefully, making the dependency explicit.
- **[Risk] Docs with replaced placeholders may confuse contributors unfamiliar with the real values** → Mitigation: A `CONTRIBUTING.md` section (or README note) will explain what each placeholder represents and where to obtain real values.

## Migration Plan

Operators running the existing stack must take the following steps after this change lands, before restarting services:

1. Copy `backend/.env.example` to `backend/.env` and fill in real values for `DATABASE_URL`, `LITELLM_BASE_URL`, `LITELLM_API_KEY`, `APP_CREDENTIALS_JSON`
2. Ensure all mobile CI build steps supply `--dart-define=BACKEND_BASE_URL=...`, `--dart-define=APP_CREDENTIAL_APP_ID=...`, `--dart-define=APP_CREDENTIAL_SECRET=...`
3. Update any shell scripts or manual notes that previously referenced the app secret placeholder with the real secret sourced from the team's password manager
4. If running E2E tests: set `BACKEND_BASE_URL`, `APP_ID`, `APP_SECRET` env vars in the test environment

No rollback plan is needed — the change is purely subtractive for secrets and additive for placeholder text. Rolling back would re-introduce the leaked values, which is undesirable.

## Open Questions

- Should `.serena/` be added to `.gitignore` entirely for future sessions, or is per-file scrubbing sufficient? (Recommend per-file for now; add `.gitignore` rule as a follow-up if memory files keep accumulating sensitive data.)
- Should a `gitleaks` or `truffleHog` pre-commit hook be added in this same change, or as a separate follow-on? (Out of scope here — flagged for a future `add-secret-scanning-ci` change.)
