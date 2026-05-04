## ADDED Requirements

### Requirement: Backend image can be built with Docker
The backend SHALL provide Docker packaging that builds a runnable backend service image.

#### Scenario: Backend image is built
- **WHEN** an operator runs the documented Docker build command or Compose build
- **THEN** Docker produces a backend image containing the Node.js service and production dependencies

#### Scenario: Backend container starts
- **WHEN** the backend image is run with required environment variables
- **THEN** the container starts the backend HTTP server on the configured port

### Requirement: Compose runs backend and PostgreSQL together
The repository SHALL provide a root `docker-compose.yml` that orchestrates the backend service and PostgreSQL database.

#### Scenario: Compose stack starts
- **WHEN** an operator runs the documented Compose start command
- **THEN** Compose starts PostgreSQL and the backend service with the backend connected to PostgreSQL

#### Scenario: Backend health is checked
- **WHEN** the Compose stack is running
- **THEN** an HTTP request to the backend health endpoint returns a successful health response

### Requirement: Compose configuration keeps deployment settings environment-configurable
The Compose deployment SHALL read runtime-specific values from environment variables instead of hard-coding secrets.

#### Scenario: LiteLLM key is supplied at runtime
- **WHEN** `LITELLM_API_KEY` is present in the operator environment or local env file
- **THEN** Compose passes the value to the backend container without storing the secret in versioned Compose defaults

#### Scenario: Backend port is customized
- **WHEN** the operator sets the backend port environment value supported by the Compose configuration
- **THEN** the backend listens on the configured container port and exposes the documented host port mapping
