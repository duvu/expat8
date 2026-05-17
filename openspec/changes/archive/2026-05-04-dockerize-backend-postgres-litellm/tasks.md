## 1. Database Persistence

- [x] 1.1 Add a PostgreSQL client dependency to `backend/package.json`.
- [x] 1.2 Add database configuration to backend config, including `DATABASE_URL` and a LiteLLM default base URL of `<YOUR_LITELLM_URL>`.
- [x] 1.3 Implement a PostgreSQL-backed store that preserves the current store interface for inserting words, fetching new/recent words, and syncing study events.
- [x] 1.4 Ensure PostgreSQL word storage serializes and deserializes topic arrays through the existing `topics_json` column.
- [x] 1.5 Ensure study-event sync remains idempotent by `client_event_id` when backed by PostgreSQL.
- [x] 1.6 Update backend server startup to use PostgreSQL when `DATABASE_URL` is configured while retaining test-friendly store injection.

## 2. Schema and Tests

- [x] 2.1 Reuse `backend/db/schema.sql` for fresh database initialization and test setup.
- [x] 2.2 Add PostgreSQL store tests covering word persistence, duplicate detection, recent-word reads, and idempotent study-event sync.
- [x] 2.3 Update API or smoke tests to exercise the PostgreSQL-backed path when a test database is available.
- [x] 2.4 Run the backend test suite and fix regressions.

## 3. Docker Deployment

- [x] 3.1 Add `backend/Dockerfile` for a production backend image using Node.js 22.
- [x] 3.2 Add `backend/.dockerignore` to keep unnecessary files out of the image build context.
- [x] 3.3 Add root `docker-compose.yml` with backend and PostgreSQL services, persistent database volume, schema initialization, health checks, and environment-variable configuration.
- [x] 3.4 Verify the backend image builds through Docker Compose.
- [x] 3.5 Verify the Compose stack can start and the backend `/health` endpoint responds successfully.

## 4. Runtime Configuration and Documentation

- [x] 4.1 Document `DATABASE_URL`, PostgreSQL Compose variables, `LITELLM_BASE_URL`, `LITELLM_API_KEY`, `LITELLM_MODEL`, and backend port configuration.
- [x] 4.2 Document local build, start, stop, logs, and health-check commands for the Docker Compose stack.
- [x] 4.3 Confirm versioned Docker and Compose files do not contain LiteLLM API secrets.
