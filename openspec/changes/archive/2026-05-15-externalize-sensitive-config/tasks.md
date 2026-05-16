## 1. Mobile Config — Remove Hardcoded Defaults

- [x] 1.1 In `mobile/lib/src/config.dart`: change `defaultValue` for `BACKEND_BASE_URL` from `'https://expat8.x51.vn'` to `''`
- [x] 1.2 In `mobile/lib/src/config.dart`: change `defaultValue` for `APP_CREDENTIAL_APP_ID` from `'expat8-mobile-app'` to `''`
- [x] 1.3 In `mobile/lib/src/config.dart`: change `defaultValue` for `APP_CREDENTIAL_SECRET` from `'expat8-mobile-secret'` to `''` In `mobile/lib/src/config.dart`: change `defaultValue` for `APP_CREDENTIAL_SECRET` from `'expat8-mobile-secret'` to `''`
- [x] 1.4 Run `cd mobile && flutter test` and confirm no tests reference the removed defaults as expected values

## 2. Backend Config — Remove Hardcoded LiteLLM URL Default

- [x] 2.1 In `backend/src/config.js`: remove `'https://lite.x51.vn'` as the fallback default for `LITELLM_BASE_URL` — change to `process.env.LITELLM_BASE_URL` (no fallback, resulting in `undefined` when unset)
- [x] 2.2 Confirm that the existing LLM generation code handles `undefined` base URL gracefully (fails the generation call with a logged error, does not crash the process) Confirm that the existing LLM generation code handles `undefined` base URL gracefully (fails the generation call with a logged error, does not crash the process)
- [x] 2.3 Run `cd backend && npm test` and confirm tests still pass (tests should not depend on the LiteLLM URL default)

## 3. Docker Compose — Replace DB Password Default

- [x] 3.1 In `docker-compose.yml`: replace all occurrences of `expat8_password` (used as inline `:-expat8_password` Compose fallback) with `CHANGEME`
- [x] 3.2 In `backend/.env.example`: verify `DATABASE_URL` uses a placeholder password (e.g., `your_db_password_here`) rather than `expat8_password`; update if needed
- [x] 3.3 Verify `backend/.env` is listed in `backend/.gitignore` or root `.gitignore`; add it if missing Verify `backend/.env` is listed in `backend/.gitignore` or root `.gitignore`; add it if missing

## 4. E2E Test — Require Explicit Env Vars

- [x] 4.1 In `backend/test/e2e_prod_test.mjs`: remove hardcoded string fallback for `BACKEND_BASE_URL` (line 13) — replace `process.env.BACKEND_BASE_URL || 'https://expat8.x51.vn'` with `process.env.BACKEND_BASE_URL`
- [x] 4.2 In `backend/test/e2e_prod_test.mjs`: remove fallback for `APP_ID` (line 14) — require it from env
- [x] 4.3 In `backend/test/e2e_prod_test.mjs`: remove fallback for `APP_SECRET` (line 15) — require it from env
- [x] 4.4 Add an explicit guard at the top of `e2e_prod_test.mjs`: if any of the three required env vars is missing, log a clear message and skip all tests (use `process.exit(0)` or `skip` so CI does not fail when running the full suite without prod vars) Add an explicit guard at the top of `e2e_prod_test.mjs`: if any of the three required env vars is missing, log a clear message and skip all tests (use `process.exit(0)` or `skip` so CI does not fail when running the full suite without prod vars)

## 5. Documentation — Replace Real Values with Placeholders

- [x] 5.1 In `README.md`: replace `expat8-mobile-secret` with `<YOUR_APP_SECRET>` and `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>` in all build command examples
- [x] 5.2 In `CLAUDE.md`: replace `expat8-mobile-secret` with `<YOUR_APP_SECRET>` and `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>` in all command examples
- [x] 5.3 In `.github/copilot-instructions.md`: replace `expat8-mobile-secret` with `<YOUR_APP_SECRET>`, `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>`, and `docker.x51.vn/x-ai/expat8-backend` with `<YOUR_REGISTRY>/expat8-backend`
- [x] 5.4 In `mobile/README.md`: replace `expat8-mobile-secret` with `<YOUR_APP_SECRET>` and `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>`
- [x] 5.5 In `docs/mvp-setup.md`: replace `https://lite.x51.vn` with `<YOUR_LITELLM_URL>`, `expat8_password` with `<YOUR_DB_PASSWORD>`, and `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>`
- [x] 5.6 In `docs/seed-vocabulary.md`: replace `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>` and `APP_SECRET=expat8-mobile-secret` with `APP_SECRET=<YOUR_APP_SECRET>`
- [x] 5.7 In `docs/mobile-system-logging.md`: replace `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>` and `APP_CREDENTIAL_SECRET=expat8-mobile-secret` with `APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>`
- [x] 5.8 In `docs/20260508-app-runtime-review.md`: replace `docker.x51.vn/x-ai/expat8-backend` with `<YOUR_REGISTRY>/expat8-backend`, `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>`, and `expat8-mobile-secret` with `<YOUR_APP_SECRET>`
- [x] 5.9 In `docs/RELEASE_NOTES_9_9.md`: replace `https://expat8.x51.vn` with `<YOUR_BACKEND_URL>` in the flutter build command
- [x] 5.10 In `backend/.env.example`: replace `dev-secret-change-me` with `<YOUR_APP_SECRET>` in the `APP_CREDENTIALS_JSON` example and replace `https://lite.x51.vn` with `<YOUR_LITELLM_URL>` In `backend/.env.example`: replace `dev-secret-change-me` with `<YOUR_APP_SECRET>` in the `APP_CREDENTIALS_JSON` example and replace `https://lite.x51.vn` with `<YOUR_LITELLM_URL>`

## 6. Serena Memory Files — Scrub Internal Infrastructure

- [x] 6.1 In `.serena/memories/expat8/deploy/2026-05-09-expat8-backend-fresh-deploy.md`: replace `10.113.213.9` with `<INTERNAL_HOST>`, replace `docker.x51.vn/x-ai/expat8-backend` with `<YOUR_REGISTRY>/expat8-backend`, replace `docker.x51.vn/x-ai/expat8-dashboard` with `<YOUR_REGISTRY>/expat8-dashboard`, and replace `expat8-mobile-secret` with `<YOUR_APP_SECRET>`
- [x] 6.2 Search all other files under `.serena/` for occurrences of `10.113`, `docker.x51.vn`, and `expat8-mobile-secret`; redact any found Search all other files under `.serena/` for occurrences of `10.113`, `docker.x51.vn`, and `expat8-mobile-secret`; redact any found

## 7. Verification

- [x] 7.1 Run `cd backend && npm test` and confirm all tests pass with no regressions
- [x] 7.2 Run `cd mobile && flutter test` and confirm all tests pass
- [x] 7.3 Search the entire repo for `expat8-mobile-secret` using `grep -r "expat8-mobile-secret" --include="*.dart" --include="*.js" --include="*.ts" --include="*.md" --include="*.yml" --include="*.yaml" .` and confirm zero hits in non-archived, non-test files
- [x] 7.4 Search for `lite.x51.vn` in source files (`*.js`, `*.ts`, `*.dart`) and confirm zero hits
- [x] 7.5 Search for `10.113.` across all files and confirm zero hits (internal IP scrubbed)
- [x] 7.6 Run `git status` and confirm `backend/.env` (if present locally) is not staged for commit
