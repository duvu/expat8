## Why

The backend needs a production-ready runtime path instead of relying on the current in-memory store and manual Node.js startup. Moving persistence to PostgreSQL and packaging the service with Docker makes the backend deployable and repeatable while keeping LiteLLM credentials environment-configurable.

## What Changes

- Add PostgreSQL-backed backend persistence for vocabulary words, study events, and user word state using the existing database schema as the contract baseline.
- Add Docker packaging for the backend service.
- Add a root `docker-compose.yml` that builds the backend image and runs it with PostgreSQL.
- Configure LiteLLM through environment variables, with `https://lite.x51.vn` as the default base URL and the API key supplied by environment.
- Document the local and deployment commands for building, starting, and verifying the backend stack.

## Capabilities

### New Capabilities
- `backend-postgres-persistence`: Backend reads and writes words, study events, and user word states through PostgreSQL instead of volatile in-memory storage.
- `backend-container-deployment`: Backend can be built and run as a Docker container, with `docker-compose.yml` orchestrating the backend and PostgreSQL services.
- `backend-litellm-runtime-config`: Backend uses environment-configurable LiteLLM endpoint, API key, and model settings suitable for deployment.

### Modified Capabilities

- None.

## Impact

- Affected code: `backend/src/config.js`, backend store/server initialization, tests, and backend package dependencies.
- New infrastructure files: backend `Dockerfile`, backend `.dockerignore`, root `docker-compose.yml`, and environment documentation.
- External dependencies: PostgreSQL database service and a Node.js PostgreSQL client library.
- Runtime configuration: database connection URL, LiteLLM base URL, LiteLLM API key, LiteLLM model, backend port, and default language settings.
