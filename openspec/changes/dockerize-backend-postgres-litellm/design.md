## Context

The backend is a Node.js 22 service using built-in HTTP primitives and an in-memory `WordStore`. It already has a SQL schema in `backend/db/schema.sql`, LiteLLM client code, and environment-based configuration for LiteLLM. The current setup is useful for tests and local smoke runs, but service restarts lose backend data and deployment still requires manual Node.js setup.

This change makes the backend deployable as a containerized service backed by PostgreSQL. The Docker Compose stack will provide a repeatable local/deployment entry point, and LiteLLM will remain fully environment-configurable with `https://lite.x51.vn` as the deployment-oriented default base URL.

## Goals / Non-Goals

**Goals:**

- Replace production backend storage with PostgreSQL for words, study events, and user word states.
- Keep API behavior compatible with the existing mobile contract.
- Add backend Docker packaging and root-level Compose orchestration for backend plus PostgreSQL.
- Make LiteLLM base URL, API key, and model configurable through environment variables.
- Provide clear build, start, health check, and test commands.

**Non-Goals:**

- Add authentication or user account flows.
- Change mobile app storage or sync behavior.
- Introduce a migration framework beyond initializing the current schema for this change.
- Deploy to a specific remote host automatically.

## Decisions

1. Use PostgreSQL through a Node PostgreSQL client with a repository-compatible store interface.

   The existing `WordStore` API already expresses the backend operations that routes need: insert/find/recent words and idempotent study-event sync. A PostgreSQL-backed implementation should preserve that interface so route behavior and tests remain focused. The alternative is to rewrite route handlers around SQL directly, but that would couple HTTP behavior to persistence details and make test setup harder.

2. Use `DATABASE_URL` as the primary database configuration.

   A single connection string works cleanly in Docker Compose, CI, and deployed environments. Separate host/user/password variables can still be derived later if a deployment target requires them. The alternative is many discrete database variables from the start, but that adds configuration surface without solving a current requirement.

3. Initialize PostgreSQL from the existing `backend/db/schema.sql`.

   The schema already captures the MVP data contract and indexes. Compose can mount it into PostgreSQL initialization for fresh local/deployment databases, while backend tests can run setup SQL directly. The alternative is adding a migration tool now, but the project has no existing migration workflow and only one schema baseline.

4. Keep LiteLLM credentials environment-only.

   `LITELLM_API_KEY` must be read from the runtime environment and never baked into images or Compose defaults. Compose should reference environment substitution or an ignored local env file. The alternative is placing a sample key in Compose, which would create a secret-leak risk.

5. Build a backend-specific Docker image from `backend/`.

   The backend package is self-contained and can use a Dockerfile in `backend/`. The root `docker-compose.yml` will build that context and wire it to PostgreSQL. The alternative is a repository-root image, but that would copy unrelated mobile and OpenSpec files into the backend image context.

## Risks / Trade-offs

- PostgreSQL startup race -> Backend should either retry database initialization or Compose should use health checks and `depends_on` conditions.
- Schema drift between SQL file and store code -> Tests should exercise PostgreSQL persistence paths against the schema.
- Existing in-memory tests may become slower if all tests require PostgreSQL -> Keep unit tests isolated where useful and add focused integration coverage for PostgreSQL-backed behavior.
- LiteLLM endpoint/key misconfiguration -> Health or startup documentation should make the required environment variables explicit without logging secrets.
- Compose is not a full production platform -> Treat it as the build/run/deployable baseline, not as a replacement for host-specific hardening.

## Migration Plan

1. Add PostgreSQL dependencies and a PostgreSQL-backed store.
2. Update server startup to use PostgreSQL when `DATABASE_URL` is configured while preserving testability.
3. Add Dockerfile, `.dockerignore`, and root `docker-compose.yml`.
4. Update backend documentation with environment variables and Compose commands.
5. Verify backend tests and a Compose build path.

Rollback is to stop the Compose stack, restore the previous backend startup path, and run the service without `DATABASE_URL`; any PostgreSQL data created during the change remains in the database volume until explicitly removed.

## Open Questions

- Whether the final deployment host will provide `LITELLM_API_KEY` through an `.env` file, shell environment, or secret manager.
- Whether persistent PostgreSQL volumes should be named for local development only or parameterized for a shared deployment host.
