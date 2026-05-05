## ADDED Requirements

### Requirement: Backend local verification is reproducible
The project SHALL document and support a reproducible backend test sequence.

#### Scenario: Backend dependencies are not installed
- **WHEN** a developer attempts backend verification without installed runtime dependencies
- **THEN** the documented sequence instructs them to run `npm ci` before `npm test`

#### Scenario: Backend tests run locally
- **WHEN** backend dependencies are installed
- **THEN** `npm test` verifies identity, feed, sync, proficiency, app credential, and runtime behavior

### Requirement: Mobile verification blockers are explicit
The project SHALL document mobile test prerequisites and report when Flutter tooling is unavailable.

#### Scenario: Flutter SDK is unavailable
- **WHEN** `flutter` is not available on PATH
- **THEN** verification output records that mobile tests could not be run and lists `flutter test` as the required command

#### Scenario: Flutter SDK is available
- **WHEN** Flutter tooling is available
- **THEN** mobile unit and widget tests are run for auth feedback, user info rendering, swipe behavior, and repository fallback

### Requirement: Signed API smoke checks are available
The project SHALL provide or document read-only signed backend smoke checks for deployed environments.

#### Scenario: Signed read-only smoke check succeeds
- **WHEN** a signed request is sent to a deployed read-only endpoint such as `/v1/words/recent`
- **THEN** the check reports HTTP 200 and validates that response JSON can be parsed

#### Scenario: Unsigned protected request is rejected
- **WHEN** an unsigned request is sent to a protected `/v1/*` endpoint
- **THEN** the check reports the expected rejection response

### Requirement: TLS chain validation is checked for mobile relevance
The project SHALL include a TLS/certificate-chain verification step for the configured backend base URL.

#### Scenario: TLS validation fails in a strict client
- **WHEN** a strict client cannot verify the backend certificate chain
- **THEN** the verification report records the failure and requires Android/iOS validation before release

#### Scenario: TLS validation succeeds in mobile-equivalent clients
- **WHEN** Android/iOS or an equivalent trust store can verify the backend certificate chain
- **THEN** the verification report records the backend URL as suitable for mobile API calls
