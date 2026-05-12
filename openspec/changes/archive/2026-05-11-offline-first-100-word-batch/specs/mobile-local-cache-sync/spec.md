## MODIFIED Requirements

### Requirement: New-word requests fall back to local storage
The mobile app SHALL use local fallback when a backend new-word request fails, times out after 5 seconds, or the device is offline. The prefetch batch size SHALL be 100 words.

#### Scenario: Backend returns within timeout
- **WHEN** the app requests a batch of 100 new words and the backend returns a valid response within 5 seconds
- **THEN** the app saves all returned words locally, and records a success log event for the remote fetch path

#### Scenario: Backend request times out
- **WHEN** the app requests a batch of 100 new words and the backend does not return within 5 seconds
- **THEN** the app uses local eligible words and records timeout and fallback-attempt log events

#### Scenario: No local new word is available
- **WHEN** backend fallback is required and no eligible local new word exists
- **THEN** the app displays an eligible review word if one is available and records a fallback-result log event indicating source selection
