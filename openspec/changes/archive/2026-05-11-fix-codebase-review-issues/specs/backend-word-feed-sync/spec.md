## MODIFIED Requirements

### Requirement: Backend supports recent-word bootstrap
The backend SHALL provide an API endpoint that returns recent vocabulary items for bootstrapping or restoring a local mobile cache, and SHALL support `exclude_server_word_id` filtering to avoid returning words already present in the client cache.

#### Scenario: Mobile requests recent words
- **WHEN** the mobile app requests recent words with a limit of 1000
- **THEN** the backend returns no more than 1000 recent vocabulary items

#### Scenario: Mobile requests recent words with exclusion list
- **WHEN** the mobile app sends one or more `exclude_server_word_id` query parameters
- **THEN** the backend omits matching words from the response, even if they would otherwise be in the result set

#### Scenario: Mobile client sends no exclusion list
- **WHEN** the mobile app requests recent words without any `exclude_server_word_id` parameter
- **THEN** the backend returns recent words unfiltered (same behavior as before)
