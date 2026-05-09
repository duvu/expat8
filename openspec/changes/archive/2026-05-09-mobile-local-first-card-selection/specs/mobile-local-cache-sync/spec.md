## MODIFIED Requirements

### Requirement: Card requests use local storage while backend refill is separate
The mobile app SHALL serve visible new/review card requests from ObjectBox local storage and SHALL use backend `/v1/learning/cards` only for inventory refill/top-up paths. The sole condition for triggering a background refill SHALL be that the count of unstudied new words for the active learning language is strictly less than 100. Total pool size and global word-count targets SHALL NOT independently trigger a server fetch.

#### Scenario: Local new word is available
- **WHEN** the app requests a new word and local storage contains at least one eligible unstudied new word
- **THEN** the app serves the word from local storage without making a backend request in the visible card path

#### Scenario: Local new word is unavailable
- **WHEN** the app requests a new word and local storage has no eligible unstudied new word
- **THEN** the app may display an eligible review word if one is available and records a local-empty diagnostic log

#### Scenario: Backend refill succeeds
- **WHEN** inventory refill or top-up requests `/v1/learning/cards` and the backend returns a valid batch
- **THEN** the app saves the returned words locally through the capped ObjectBox write path

#### Scenario: Backend refill fails
- **WHEN** inventory refill or top-up fails due to timeout, network error, or backend rejection
- **THEN** the app logs the failure and continues serving any available local cards without blocking the visible session

#### Scenario: Unstudied count below threshold triggers refill
- **WHEN** the count of unstudied new words for the active language is strictly less than 100
- **THEN** the app SHALL trigger a background refill from the server

#### Scenario: Unstudied count at or above threshold suppresses refill
- **WHEN** the count of unstudied new words for the active language is 100 or greater
- **THEN** the app SHALL NOT make a backend request, even if the total local word count is below any pool-size target

#### Scenario: Seed vocabulary is healthy at startup
- **WHEN** the app seeds bundle vocabulary and the resulting unstudied count for the active language is 100 or greater
- **THEN** the startup top-up path does NOT fetch from the backend

#### Scenario: Refill check runs after new-word state transition
- **WHEN** a new-word card is shown and `markWordAsLearning` completes
- **THEN** the app runs the unstudied threshold check in the completion callback, ensuring the count has already been decremented before deciding whether to fetch
