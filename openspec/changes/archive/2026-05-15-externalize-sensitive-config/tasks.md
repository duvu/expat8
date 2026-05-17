## 1. Mobile Config — Remove Hardcoded Defaults

- [x] 1.1 In `mobile/lib/src/config.dart`: change `defaultValue` for `BACKEND_BASE_URL` from `'<YOUR_BACKEND_URL>'` to `''`
- [x] 1.2 In `mobile/lib/src/config.dart`: change `defaultValue` for `APP_CREDENTIAL_APP_ID` from `'expat8-mobile-app'` to `''`
- [x] 1.3 In `mobile/lib/src/config.dart`: change `defaultValue` for `APP_CREDENTIAL_SECRET` from `'<YOUR_APP_SECRET>'` to `''` In `mobile/lib/src/config.dart`: change `defaultValue` for `APP_CREDENTIAL_SECRET` from `'<YOUR_APP_SECRET>'` to `''`
- [x] 1.4 Run `cd mobile && flutter test` and confirm no tests reference the removed defaults as expected values

## 2. Backend Config — Remove Hardcoded LiteLLM URL Default

- [x] 2.1 In `backend/src/config.js`: remove `'<YOUR_LITELLM_URL>'` as the fallback default for `LITELLM_BASE_URL` — change to `process.env.LITELLM_BASE_URL` (no fallback, resulting in `undefined` when unset)
- [x] 2.2 Confirm that the existing LLM generation code handles `undefined` base URL gracefully (fails the generation call with a logged error, does not crash the process) Confirm that the existing LLM generation code handles `undefined` base URL gracefully (fails the generation call with a logged error, does not crash the process)
- [x] 2.3 Run `cd backend && npm test` and confirm tests still pass (tests should not depend on the LiteLLM URL default)

## 3. Docker Compose — Replace DB Password Default

- [x] 3.1 In `docker-compose.yml`: replace all occurrences of `<YOUR_DB_PASSWORD>` (used as inline `:-<YOUR_DB_PASSWORD>` Compose fallback) with `CHANGEME`
- [x] 3.2 In `backend/.env.example`: verify `DATABASE_URL` uses a placeholder password (e.g., `your_db_password_here`) rather than `<YOUR_DB_PASSWORD>`; update if needed
- [x] 3.3 Verify `backend/.env` is listed in `backend/.gitignore` or root `.gitignore`; add it if missing Verify `backend/.env` is listed in `backend/.gitignore` or root `.gitignore`; add it if missing

## 4. E2E Test — Require Explicit Env Vars

- [x] 4.1 In `backend/test/e2e_prod_test.mjs`: remove hardcoded string fallback for `BACKEND_BASE_URL` (line 13) — replace `process.env.BACKEND_BASE_URL || '<YOUR_BACKEND_URL>'` with `process.env.BACKEND_BASE_URL`
- [x] 4.2 In `backend/test/e2e_prod_test.mjs`: remove fallback for `APP_ID` (line 14) — require it from env
- [x] 4.3 In `backend/test/e2e_prod_test.mjs`: remove fallback for `APP_SECRET` (line 15) — require it from env
- [x] 4.4 Add an explicit guard at the top of `e2e_prod_test.mjs`: if any of the three required env vars is missing, log a clear message and skip all tests (use `process.exit(0)` or `skip` so CI does not fail when running the full suite without prod vars) Add an explicit guard at the top of `e2e_prod_test.mjs`: if any of the three required env vars is missing, log a clear message and skip all tests (use `process.exit(0)` or `skip` so CI does not fail when running the full suite without prod vars)

## 5. Documentation — Replace Real Values with Placeholders

- [x] 5.1 In `README.md`: replace `<YOUR_APP_SECRET>` with `<YOUR_APP_SECRET>` and `<YOUR_BACKEND_URL>` with `<YOUR_BACKEND_URL>` in all build command examples
- [x] 5.2 In `CLAUDE.md`: replace `<YOUR_APP_SECRET>` with `<YOUR_APP_SECRET>` and `<YOUR_BACKEND_URL>` with `<YOUR_BACKEND_URL>` in all command examples
- [x] 5.3 In `.github/copilot-instructions.md`: replace secret, URL, and registry references with placeholders
- [x] 5.4 In `mobile/README.md`: replace `<YOUR_APP_SECRET>` with `<YOUR_APP_SECRET>` and `<YOUR_BACKEND_URL>` with `<YOUR_BACKEND_URL>`
- [x] 5.5 In `docs/mvp-setup.md`: replace `<YOUR_LITELLM_URL>` with `<YOUR_LITELLM_URL>`, `<YOUR_DB_PASSWORD>` with `<YOUR_DB_PASSWORD>`, and `<YOUR_BACKEND_URL>` with `<YOUR_BACKEND_URL>`
- [x] 5.6 In `docs/seed-vocabulary.md`: replace `<YOUR_BACKEND_URL>` with `<YOUR_BACKEND_URL>` and `APP_SECRET=<YOUR_APP_SECRET>` with `APP_SECRET=<YOUR_APP_SECRET>`
- [x] 5.7 In `docs/mobile-system-logging.md`: replace `<YOUR_BACKEND_URL>` with `<YOUR_BACKEND_URL>` and `APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>` with `APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>`
- [x] 5.8 In `docs/20260508-app-runtime-review.md`: replace registry, URL, and secret references with placeholders
- [x] 5.9 In `docs/RELEASE_NOTES_9_9.md`: replace `<YOUR_BACKEND_URL>` with `<YOUR_BACKEND_URL>` in the flutter build command
- [x] 5.10 In `backend/.env.example`: replace `CHANGE_ME` with `<YOUR_APP_SECRET>` in the `APP_CREDENTIALS_JSON` example and replace `<YOUR_LITELLM_URL>` with `<YOUR_LITELLM_URL>` In `backend/.env.example`: replace `CHANGE_ME` with `<YOUR_APP_SECRET>` in the `APP_CREDENTIALS_JSON` example and replace `<YOUR_LITELLM_URL>` with `<YOUR_LITELLM_URL>`

## 6. Serena Memory Files — Scrub Internal Infrastructure

- [x] 6.1 In `.serena/memories/expat8/deploy/2026-05-09-expat8-backend-fresh-deploy.md`: replace internal host, registry paths, and secret references with placeholders
- [x] 6.2 Search all other files under `.serena/` for occurrences of internal hosts, registry paths, and secret references; redact any found

## 7. Verification

- [x] 7.1 Run `cd backend && npm test` and confirm all tests pass with no regressions
- [x] 7.2 Run `cd mobile && flutter test` and confirm all tests pass
- [x] 7.3 Search the entire repo for placeholder patterns and confirm no real secrets remain in non-archived, non-test files
- [x] 7.4 Search for `lite.x51.vn` in source files (`*.js`, `*.ts`, `*.dart`) and confirm zero hits
- [x] 7.5 Search for `<INTERNAL_HOST>.` across all files and confirm zero hits (internal IP scrubbed)
- [x] 7.6 Run `git status` and confirm `backend/.env` (if present locally) is not staged for commit
