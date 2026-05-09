## MODIFIED Requirements

### Requirement: Compose runs backend, dashboard, and PostgreSQL together
The repository SHALL provide a root `docker-compose.yml` that orchestrates the backend service, dashboard service, and PostgreSQL database.

#### Scenario: Compose stack starts
- **WHEN** an operator runs the documented Compose start command
- **THEN** Compose starts PostgreSQL, the backend service, and the dashboard service with the backend connected to PostgreSQL

#### Scenario: Backend health is checked
- **WHEN** the Compose stack is running
- **THEN** an HTTP request to the backend health endpoint returns a successful health response

#### Scenario: Dashboard becomes available
- **WHEN** the Compose stack is running
- **THEN** the dashboard service is reachable on its configured host port

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
