## Purpose
Define how the backend loads its LiteLLM endpoint URL from runtime configuration rather than hard-coding it.

## Requirements

### Requirement: Backend uses configurable LiteLLM endpoint
The backend SHALL read the LiteLLM base URL from environment configuration and default to `https://lite.x51.vn` when no override is provided.

#### Scenario: LiteLLM base URL is omitted
- **WHEN** the backend starts without `LITELLM_BASE_URL`
- **THEN** the backend uses `https://lite.x51.vn` as the LiteLLM base URL

#### Scenario: LiteLLM base URL is provided
- **WHEN** the backend starts with `LITELLM_BASE_URL`
- **THEN** the backend sends LiteLLM requests to the configured base URL

### Requirement: Backend uses environment-provided LiteLLM API key
The backend SHALL read the LiteLLM API key from environment configuration and SHALL NOT hard-code the key in source, Dockerfile, or Compose defaults.

#### Scenario: LiteLLM API key is provided
- **WHEN** the backend starts with `LITELLM_API_KEY`
- **THEN** LiteLLM requests include the configured API key

#### Scenario: LiteLLM API key is missing
- **WHEN** the backend starts without `LITELLM_API_KEY`
- **THEN** the backend still starts and handles AI generation failures without exposing any secret value

### Requirement: Backend keeps LiteLLM model configurable
The backend SHALL read the LiteLLM model from environment configuration while preserving a default model value.

#### Scenario: LiteLLM model is provided
- **WHEN** the backend starts with `LITELLM_MODEL`
- **THEN** the backend requests vocabulary generation with the configured model

#### Scenario: LiteLLM model is omitted
- **WHEN** the backend starts without `LITELLM_MODEL`
- **THEN** the backend uses its documented default LiteLLM model
