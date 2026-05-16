# mobile-app-credential-signing Specification

## Purpose
TBD - created by archiving change resolve-codebase-consistency-drift. Update Purpose after archive.
## Requirements
### Requirement: Mobile signs `/v1/*` requests using the backend credential contract
The mobile app SHALL generate app credential headers for `/v1/*` requests using the same canonical request structure verified by the backend.

#### Scenario: Mobile sends a signed GET request
- **WHEN** the mobile app sends a signed GET request with query parameters
- **THEN** it signs the upper-case method, sorted path and query, timestamp, nonce, and empty-body content hash using the configured app secret

#### Scenario: Mobile sends a signed JSON request
- **WHEN** the mobile app sends a signed POST or PUT request with a JSON body
- **THEN** it signs the exact UTF-8 request body bytes used as the transmitted body

#### Scenario: User session is present
- **WHEN** the mobile app sends a signed request with a user session
- **THEN** it includes the bearer session token while preserving the app credential signature required for `/v1/*`

### Requirement: Mobile app credential values SHALL have no non-empty compile-time defaults
`APP_CREDENTIAL_APP_ID` and `APP_CREDENTIAL_SECRET` MUST be supplied via `--dart-define` at build time. The `String.fromEnvironment` calls in `config.dart` MUST use an empty string as the default value (not a real credential). If either value is empty at runtime, the app MUST surface a connection failure rather than silently authenticating with a leaked credential.

#### Scenario: App built without --dart-define credential flags
- **WHEN** the Flutter app is compiled without `--dart-define=APP_CREDENTIAL_APP_ID` or `--dart-define=APP_CREDENTIAL_SECRET`
- **THEN** `AppConfig.appCredentialAppId` and `AppConfig.appCredentialSecret` are empty strings

#### Scenario: App makes API request with empty credential
- **WHEN** the app attempts a signed request with an empty `APP_CREDENTIAL_SECRET`
- **THEN** the backend rejects the request (401) rather than the app crashing silently or leaking a real secret

### Requirement: Mobile backend URL SHALL have no non-empty compile-time default
`BACKEND_BASE_URL` MUST be supplied via `--dart-define` at build time. The `String.fromEnvironment` call MUST use an empty string as the default. A build that omits this flag MUST NOT silently route traffic to any production or staging backend.

#### Scenario: App built without --dart-define BACKEND_BASE_URL
- **WHEN** the Flutter app is compiled without `--dart-define=BACKEND_BASE_URL`
- **THEN** `AppConfig.backendBaseUrl` is an empty string and the first network request fails immediately with a connection error

### Requirement: Mobile credential nonces are random and unique within the replay window
The mobile app MUST generate a high-entropy nonce for every signed request and MUST NOT derive credential nonces solely from timestamps or counters.

#### Scenario: Concurrent requests are signed
- **WHEN** the mobile app signs multiple requests in the same clock tick or microsecond
- **THEN** each request receives a distinct random nonce

#### Scenario: Backend replay protection is active
- **WHEN** the backend rejects repeated nonces within the replay window
- **THEN** normal mobile request concurrency does not reuse a nonce and trigger false replay rejection

