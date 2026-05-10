## MODIFIED Requirements

### Requirement: Compose runs backend, dashboard, PostgreSQL, and article-processing worker together
The repository SHALL provide a root `docker-compose.yml` that orchestrates the backend service, dashboard service, PostgreSQL database, and the dedicated article-processing worker.

#### Scenario: Compose stack starts
- **WHEN** an operator runs the documented Compose start command
- **THEN** Compose starts PostgreSQL, the backend service, the dashboard service, and the article-processing worker with shared database access

#### Scenario: Backend health is checked
- **WHEN** the Compose stack is running
- **THEN** an HTTP request to the backend health endpoint returns a successful health response

#### Scenario: Dashboard becomes available
- **WHEN** the Compose stack is running
- **THEN** the dashboard service is reachable on its configured host port

#### Scenario: Worker can consume article jobs
- **WHEN** the Compose stack is running and an article job exists
- **THEN** the article-processing worker can claim the job and process article vocabulary without manual intervention

### Requirement: Compose configuration keeps deployment settings environment-configurable
The Compose deployment SHALL read runtime-specific values from environment variables instead of hard-coding secrets or service URLs.

#### Scenario: LiteLLM key is supplied at runtime
- **WHEN** `LITELLM_API_KEY` is present in the operator environment or local env file
- **THEN** Compose passes the value to the backend containers without storing the secret in versioned Compose defaults

#### Scenario: Worker runtime is customized
- **WHEN** the operator sets the article worker interval, retry cap, or service image values supported by Compose
- **THEN** Compose passes those values to the worker container without hard-coding deployment-specific settings

#### Scenario: Dashboard environment is customized
- **WHEN** the operator sets the dashboard backend URL, admin token, or dashboard port environment values
- **THEN** Compose passes those values to the dashboard container without hard-coding deployment-specific settings
