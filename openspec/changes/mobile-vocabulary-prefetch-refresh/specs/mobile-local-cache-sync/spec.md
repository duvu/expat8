## MODIFIED Requirements

### Requirement: New-word requests fall back to local storage
The mobile app SHALL use local fallback when a backend new-word request fails, times out after 5 seconds, or the device is offline, and SHALL emit diagnostic logs for request attempts, fallback decisions, and fallback outcomes. New words SHALL always be served from the local database; on-demand backend fetch is a last-resort fallback only when local storage is empty.

#### Scenario: Backend returns within timeout
- **WHEN** the app requests a new word and local storage is empty and the backend returns a valid response within 5 seconds
- **THEN** the app saves the returned word locally, displays it, and records a success log event for the remote fetch path

#### Scenario: Backend request times out
- **WHEN** the app requests a new word, local storage is empty, and the backend does not return within 5 seconds
- **THEN** the app displays an eligible review word if one is available and records timeout and fallback-attempt log events

#### Scenario: No local new word is available
- **WHEN** backend fallback is required and no eligible local new word exists
- **THEN** the app displays an eligible review word if one is available and records a fallback-result log event indicating source selection

#### Scenario: Local new word is available
- **WHEN** the app requests a new word and local storage contains at least one unstudied new word
- **THEN** the app serves the word from local storage without making a backend request
