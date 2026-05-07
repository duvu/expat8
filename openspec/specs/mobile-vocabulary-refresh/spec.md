## ADDED Requirements

### Requirement: App refreshes vocabulary daily at 15% rate
The mobile app SHALL replace approximately 15% of stored vocabulary words with new words from the backend each calendar day, maintaining a local store of no more than 1000 words.

#### Scenario: First access of a new calendar day
- **WHEN** the app starts and the stored `last_daily_refresh_date` differs from the current calendar date
- **THEN** the app triggers a background daily refresh to fetch approximately 150 new words and updates `last_daily_refresh_date`

#### Scenario: Daily refresh fetches new words
- **WHEN** the daily refresh worker runs
- **THEN** it fetches up to 150 vocabulary words not already present in local storage and upserts them into the local word store

#### Scenario: Local word count after daily refresh
- **WHEN** the daily refresh upsert would cause the local count to exceed 1000
- **THEN** the app removes the oldest already-studied words first to stay within the 1000-word limit

#### Scenario: Daily refresh fails due to network error
- **WHEN** the daily refresh worker encounters a network error
- **THEN** the app logs a warning, does not update `last_daily_refresh_date`, and retries on the next app launch or explicit trigger

### Requirement: App proactively refreshes vocabulary after study milestones
The mobile app SHALL trigger a proactive vocabulary refresh when the ratio of unstudied new words falls below 15 per 100 words studied since the last refresh.

#### Scenario: Study milestone triggers refresh check
- **WHEN** the user completes rating a word and the `words_studied_since_last_refresh` counter reaches a multiple of 100
- **THEN** the app checks whether the count of unstudied new words in local storage is below 15

#### Scenario: Proactive refresh is needed
- **WHEN** the refresh check finds fewer than 15 unstudied new words in local storage
- **THEN** the app triggers `VocabularyRefreshWorker` to fetch additional new words from the backend

#### Scenario: Proactive refresh is not needed
- **WHEN** the refresh check finds 15 or more unstudied new words in local storage
- **THEN** the app does not trigger a backend fetch and increments the counter for the next milestone check

#### Scenario: Refresh worker runs while offline
- **WHEN** a proactive or daily refresh is triggered and the device is offline
- **THEN** the app logs the failure, does not update refresh state, and continues serving words from local storage without blocking the session
