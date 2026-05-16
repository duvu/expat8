## Purpose
Define the requirement that no credential, private URL, or internal hostname may appear as a hardcoded value in source code, default configuration, or checked-in documentation when the repository is public.

## Requirements

### Requirement: Source code SHALL NOT contain hardcoded production credentials or private URLs as default values
No source file (`.dart`, `.js`, `.ts`, etc.) SHALL use a real production secret, API key, or private infrastructure URL as a compile-time or runtime default value. Any configuration that varies per deployment MUST be supplied via environment variables or `--dart-define` flags with no non-empty fallback.

#### Scenario: Mobile app built without dart-defines
- **WHEN** the Flutter app is built without `--dart-define=APP_CREDENTIAL_SECRET` or `--dart-define=BACKEND_BASE_URL`
- **THEN** `AppConfig.appCredentialSecret` and `AppConfig.backendBaseUrl` are empty strings, and the first API request fails with a connection error rather than silently using a production credential

#### Scenario: Backend started without LiteLLM URL
- **WHEN** the backend starts without `LITELLM_BASE_URL` in the environment
- **THEN** `config.litellmBaseUrl` is `undefined` or `null`, and LLM generation requests fail with a clear configuration error rather than routing to a private proxy URL

#### Scenario: Docker Compose started without a `.env` file
- **WHEN** `docker compose up` is run without a `.env` file
- **THEN** the DB password default is `CHANGEME` (an obviously non-functional placeholder) and not a real credential

### Requirement: Documentation and scripts SHALL use placeholders for all sensitive values
All checked-in documentation files (`.md`, `.txt`), shell scripts, and CI configuration MUST replace real credentials, private hostnames, and internal IP addresses with clearly-marked placeholder tokens such as `<YOUR_APP_SECRET>`, `<YOUR_BACKEND_URL>`, or `<YOUR_REGISTRY>`. Placeholder tokens MUST begin with `<` and end with `>` and MUST describe what value is expected.

#### Scenario: README build command reviewed
- **WHEN** a contributor reads the build command in `README.md` or `mobile/README.md`
- **THEN** all `--dart-define` values that carry credentials or private URLs are shown as `<placeholder>` tokens, not real values

#### Scenario: Copilot/AI instructions file reviewed
- **WHEN** `.github/copilot-instructions.md` or `CLAUDE.md` is reviewed
- **THEN** no real app secret, private Docker registry hostname, or production URL appears verbatim

### Requirement: `.env` files with real values SHALL NOT be tracked by git
The `backend/.env` file (and any `.env.local`, `.env.production`, etc.) MUST be listed in `.gitignore`. Only `.env.example` files with placeholder values MAY be tracked.

#### Scenario: `.env` file committed accidentally
- **WHEN** a developer runs `git add .`
- **THEN** `backend/.env` is excluded by `.gitignore` and does not appear in the staged files

#### Scenario: `.env.example` is checked in
- **WHEN** `backend/.env.example` is reviewed
- **THEN** all secret-valued fields contain placeholder strings (e.g., `dev-secret-change-me`, `CHANGE_ME`) and not real production or staging credentials

### Requirement: Memory and ephemeral files SHALL NOT expose internal network topology
Files in `.serena/` or similar AI-agent memory directories that are committed to the repository MUST NOT contain internal server IP addresses, internal hostnames, or private Docker registry paths. Such values MUST be redacted to `<INTERNAL_IP>`, `<INTERNAL_HOST>`, or `<PRIVATE_REGISTRY>` before commit.

#### Scenario: Serena memory file with internal IP is reviewed
- **WHEN** any file under `.serena/` is read
- **THEN** no private IP address (RFC 1918 range: `10.x.x.x`, `172.16-31.x.x`, `192.168.x.x`) or private registry hostname appears verbatim
