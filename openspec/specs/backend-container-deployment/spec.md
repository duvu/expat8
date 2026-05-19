## Purpose
Define how the backend image and root Compose stack package the backend, dashboard, and PostgreSQL services with environment-driven runtime settings, including LiteLLM configuration.
## Requirements
### Requirement: Backend image can be built with Docker
The backend SHALL provide Docker packaging that builds a runnable backend service image and supports tagged publication to `<YOUR_REGISTRY>/expat8-backend`. The dashboard SHALL likewise be packaged as `<YOUR_REGISTRY>/expat8-dashboard` using the same tag convention.

#### Scenario: Backend image is built and tagged
- **WHEN** an operator builds backend image with a timestamp tag
- **THEN** Docker produces an image tagged as `<YOUR_REGISTRY>/expat8-backend:<YYYYMMDD.HHMM>`

#### Scenario: Dashboard image is built and tagged
- **WHEN** an operator builds dashboard image with the same timestamp tag
- **THEN** Docker produces an image tagged as `<YOUR_REGISTRY>/expat8-dashboard:<YYYYMMDD.HHMM>`

#### Scenario: Tagged images are pushed to registry
- **WHEN** operator executes push for both tagged images
- **THEN** the registry stores both images and returns valid digests for deployment tracking

#### Scenario: Backend container starts
- **WHEN** the backend image is run with required environment variables
- **THEN** the container starts the backend HTTP server on the configured port

### Requirement: Compose runs backend and PostgreSQL together
The deployment process SHALL recreate both `expat8-backend` and `expat8-dashboard` from `~/deployment/worker-z440` using image tags updated in `docker-compose.yml`.

#### Scenario: Worker-z440 deploy is updated for both services
- **WHEN** operator updates `~/deployment/worker-z440/docker-compose.yml` image tags for both `expat8-backend` and `expat8-dashboard`
- **THEN** `docker compose up -d --force-recreate expat8-backend expat8-dashboard` from that directory starts both containers with the new image tags

#### Scenario: Deployment verification passes
- **WHEN** redeploy finishes
- **THEN** `docker compose ps` shows both services healthy and `curl` against `http://<INTERNAL_HOST>:18787/health` returns success

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

