## Purpose
Define how the backend image and root Compose stack package the backend, dashboard, and PostgreSQL services with environment-driven runtime settings, including LiteLLM configuration.

## Requirements
### Requirement: Backend image can be built with Docker
The backend SHALL provide Docker packaging that builds a runnable backend service image and supports tagged publication to `<YOUR_REGISTRY>/expat8-backend`.

#### Scenario: Backend image is built and tagged
- **WHEN** an operator builds backend image with a timestamp tag
- **THEN** Docker produces an image tagged as `<YOUR_REGISTRY>/expat8-backend:<YYYYMMDD.HHMM>`

#### Scenario: Tagged image is pushed to registry
- **WHEN** operator executes push for the tagged image
- **THEN** the registry stores the image and returns a valid digest for deployment tracking

#### Scenario: Backend container starts
- **WHEN** the backend image is run with required environment variables
- **THEN** the container starts the backend HTTP server on the configured port

### Requirement: Compose runs backend and PostgreSQL together
The deployment process SHALL recreate `expat8-backend` from `~/deployment/worker-z440` using the image tag updated in `docker-compose.yml`, instead of relying on local repository compose stack.

#### Scenario: Worker-z440 deploy is updated
- **WHEN** operator updates `~/deployment/worker-z440/docker-compose.yml` image tag for `expat8-backend`
- **THEN** `docker compose up -d --force-recreate expat8-backend` from that directory starts container with the new image tag

#### Scenario: Deployment verification passes
- **WHEN** backend redeploy finishes
- **THEN** `docker compose ps expat8-backend` shows healthy status and `curl` against `http://<INTERNAL_HOST>:18787/health` returns success

### Requirement: Compose configuration keeps deployment settings environment-configurable
The Compose deployment SHALL read runtime-specific values from environment variables instead of hard-coding secrets or service URLs.

#### Scenario: LiteLLM key is supplied at runtime
- **WHEN** `LITELLM_API_KEY` is present in the operator environment or local env file
- **THEN** Compose passes the value to the backend container without storing the secret in versioned Compose defaults

#### Scenario: Backend port is customized
- **WHEN** the operator sets the backend port environment value supported by the Compose configuration
- **THEN** the backend listens on the configured container port and exposes the documented host port mapping

#### Scenario: Dashboard environment is customized
- **WHEN** the operator sets the dashboard backend URL, admin token, or dashboard port environment values
- **THEN** Compose passes those values to the dashboard container without hard-coding deployment-specific settings
