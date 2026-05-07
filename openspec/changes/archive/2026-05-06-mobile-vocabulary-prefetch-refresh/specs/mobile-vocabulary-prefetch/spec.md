## ADDED Requirements

### Requirement: App pre-loads vocabulary on first install
The mobile app SHALL download up to 1000 vocabulary words from the backend into local storage on the first launch, before the user begins studying, and SHALL record prefetch progress in persistent settings.

#### Scenario: First launch detected
- **WHEN** the app starts and the `is_prefetch_done` flag is absent or false in local settings
- **THEN** the app triggers a background vocabulary prefetch and sets a pending prefetch state

#### Scenario: Prefetch completes successfully
- **WHEN** the prefetch worker downloads vocabulary from the backend and upserts up to 1000 words into local storage
- **THEN** the app marks `is_prefetch_done` as true in local settings and the local word count reaches up to 1000

#### Scenario: Prefetch is interrupted by network error
- **WHEN** the prefetch worker encounters a network error during download
- **THEN** the app logs a warning, does not mark prefetch as done, and retries on the next app launch

#### Scenario: User starts studying before prefetch completes
- **WHEN** the user requests a word card while prefetch is still in progress
- **THEN** the app serves words from whatever is already in local storage or falls back to on-demand backend fetch, without blocking on the prefetch operation

#### Scenario: Prefetch is skipped on subsequent launches
- **WHEN** the app starts and `is_prefetch_done` is true
- **THEN** the app does not re-run the bulk prefetch
