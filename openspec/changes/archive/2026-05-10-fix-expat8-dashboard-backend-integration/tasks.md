## 1. Dashboard Runtime Fix

- [x] 1.1 Update dashboard deployment wiring so `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, and `ADMIN_TOKEN` are present in the worker environment
- [x] 1.2 Confirm `BACKEND_BASE_URL` and `EXPAT8_DASHBOARD_DATABASE_URL` point at the expat8 worker backend and expat8 PostgreSQL database
- [x] 1.3 Make the dashboard fail fast with a clear runtime error when required credentials are missing

## 2. Backend Compatibility Check

- [x] 2.1 Verify the live expat8 PostgreSQL schema includes the tables and indexes required by the dashboard pages and speaking summary flows
- [x] 2.2 Confirm the worker `expat8-backend` image supports the speaking-prompts and speaking-summary routes used by the dashboard
- [x] 2.3 Fix any deployment or schema mismatch discovered during verification before redeploying the dashboard

## 3. Rollout Verification

- [x] 3.1 Redeploy `expat8-dashboard` in the worker stack with the corrected runtime envs
- [x] 3.2 Smoke test dashboard SSR pages: home, article detail, vocabulary review, and speaking-prompts review
- [x] 3.3 Verify dashboard mutations succeed against `expat8-backend` for article review and speaking-prompt approval flows
- [x] 3.4 Capture the final worker logs and mark the rollout successful only if no SSR exceptions remain
